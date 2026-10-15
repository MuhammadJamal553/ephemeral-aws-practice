terraform {
    required_providers{
        aws = {
            source = "hashicorp/aws"
            version= "~> 5.0"
        }
    }
}

provider "aws" {
    region  = "us-east-1"
}

# 1. Zip the Python tracking package automatically
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file = "lambda_function.py"
    output_path  = "lambda_function.zip"
}

# 2. Provision the Managed Amazon DynamoDB NoSQL Table
resource "aws_dynamodb_table" "portfolio_metrics" {
    name        = "jamal-khan-marathon-metrics-day6"
    billing_mode= "PAY_PER_REQUEST" # On-Demand scaling strategy (Fits inside your credit cushion completely)
    hash_key    = "MetricName" # Partition Key (Primary Key parameter mapping)

    attribute {
        name = "MetricName"
        type = "S" #string type specification
    }
}

# 3. Create the Execution IAM Role for your Lambda Engine
resource "aws_iam_role" "lambda_role" {
    name                = "jamal_khan_marathon_lambda_role_day6"   


    assume_role_policy  = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Action  = "sts:AssumeRole"
            Effect  = "Allow"
            Principal= {Service = "lambda.amazonaws.com"}
        }]
    })
}

# 4. Attach base CloudWatch execution tracking metrics access authorization policies
resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role        = aws_iam_role.lambda_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 5. CRUCIAL EXAM TASK: Principle of Least Privilege Database Policy Block
resource "aws_iam_role_policy" "lambda_dynamodb" {
    name    = "lambda_dynamo_read_write_policy"
    role    = aws_iam_role.lambda_role.id

    policy  = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Sid     = "AllowLambdaReadWriteOnMetricsTable"
            Effect  = "Allow"
            Action  = [
                "dynamodb:UpdateItem",
                "dynamodb:GetItem"
            ]
            Resource = aws_dynamodb_table.portfolio_metrics.arn # Tight structural resource target isolation
        }]
    })
}
# 6. Provision your Lambda Function with database dynamic parameter environmental binding
resource "aws_lambda_function" "my_lambda" {
    filename        = data.archive_file.lambda_zip.output_path
    function_name   = "jamal-khan-resume-backend-day6"
    role            = aws_iam_role.lambda_role.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash= data.archive_file.lambda_zip.output_base64sha256
    runtime         = "python3.12"

    environment {
        variables ={
            DYNAMODB_TABLE = aws_dynamodb_table.portfolio_metrics.name
        }
    }
}

# 7. Spin up the Public HTTP API Front Door Routing Gateway
resource "aws_apigatewayv2_api" "http_api" {
    name            = "jamal-khan-portfolio-api-day6"
    protocol_type   = "HTTP"
}

# 8. Bridge public gateway endpoints directly to your serverless backend
resource "aws_apigatewayv2_integration" "api_lambda_link" {
    api_id          = aws_apigatewayv2_api.http_api.id
    integration_type= "AWS_PROXY"
    integration_uri = aws_lambda_function.my_lambda.invoke_arn
}

# 9. Map API route listeners
resource "aws_apigatewayv2_route" "api_route" {
    api_id      = aws_apigatewayv2_api.http_api.id
    route_key   = "ANY /"
    target      = "integrations/${aws_apigatewayv2_integration.api_lambda_link.id}"
}

# 10. Automatically compile default deploy paths
resource "aws_apigatewayv2_stage" "api_stage" {
    api_id      = aws_apigatewayv2_api.http_api.id
    name        = "$default"
    auto_deploy = true 
}

# 11. Security trust firewall triggers
resource "aws_lambda_permission" "allow_api" {
    statement_id    = "AllowExecutionFromAPIGateway"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.my_lambda.function_name
    principal       = "apigateway.amazonaws.com"
    source_arn      = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# 12. Output the endpoint URL directly to the terminal
output "api_endpoint" {
    value   = aws_apigatewayv2_stage.api_stage.invoke_url
}