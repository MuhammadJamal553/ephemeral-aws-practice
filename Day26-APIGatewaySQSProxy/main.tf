terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway = "http://127.0.0.1:4566"
    iam        = "http://127.0.0.1:4566"
    sqs        = "http://127.0.0.1:4566"
  }
}

# 1. Target SQS Ingestion Queue
resource "aws_sqs_queue" "ingestion_queue" {
  name = "day26-direct-ingestion-queue"
}

# 2. IAM Role Allowing API Gateway to Send Messages to SQS
resource "aws_iam_role" "apigw_sqs_role" {
  name = "day26_apigw_sqs_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "apigw_sqs_policy" {
  name = "day26_apigw_sqs_send"
  role = aws_iam_role.apigw_sqs_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.ingestion_queue.arn
    }]
  })
}

# 3. REST API Gateway & /orders Resource
resource "aws_api_gateway_rest_api" "ingest_api" {
  name = "day26-direct-sqs-api"
}

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.ingest_api.id
  parent_id   = aws_api_gateway_rest_api.ingest_api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "post_order" {
  rest_api_id   = aws_api_gateway_rest_api.ingest_api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "NONE"
}

# 4. Direct AWS Service Integration (API Gateway -> SQS SendMessage)
resource "aws_api_gateway_integration" "sqs_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ingest_api.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.post_order.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:us-east-1:sqs:path/000000000000/${aws_sqs_queue.ingestion_queue.name}"
  credentials             = aws_iam_role.apigw_sqs_role.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  # VTL Mapping Template: Converts incoming JSON body into an SQS SendMessage action
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.ingest_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_order.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "sqs_response" {
  rest_api_id = aws_api_gateway_rest_api.ingest_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_order.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  depends_on  = [aws_api_gateway_integration.sqs_integration]
}

# 5. Deploy API Stage
resource "aws_api_gateway_deployment" "prod_deploy" {
  rest_api_id = aws_api_gateway_rest_api.ingest_api.id
  depends_on  = [aws_api_gateway_integration_response.sqs_response]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.ingest_api.id
  stage_name    = "prod"
}

output "api_id" {
  value = aws_api_gateway_rest_api.ingest_api.id
}

output "queue_url" {
  value = aws_sqs_queue.ingestion_queue.url
}
