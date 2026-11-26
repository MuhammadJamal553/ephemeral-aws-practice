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

  # Direct LocalStack Endpoint Routing (Zero DNS hang!)
  endpoints {
    dynamodb = "http://localhost:4566"
    iam      = "http://localhost:4566"
    lambda   = "http://localhost:4566"
    logs     = "http://localhost:4566"
  }
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# 1. DynamoDB Table with Streams Enabled
resource "aws_dynamodb_table" "orders_table" {
  name             = "day25-orders-cdc-table"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "OrderId"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES" # Captures before & after snapshots

  attribute {
    name = "OrderId"
    type = "S"
  }
}

# 2. IAM Execution Role for Lambda
resource "aws_iam_role" "lambda_cdc_role" {
  name = "day25_lambda_cdc_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 3. Least-Privilege Policy to Read DynamoDB Stream Shards
resource "aws_iam_role_policy" "dynamodb_stream_read" {
  name = "day25_dynamodb_stream_policy"
  role = aws_iam_role.lambda_cdc_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.orders_table.stream_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 4. Lambda Stream Consumer Function
resource "aws_lambda_function" "cdc_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "day25-cdc-stream-processor"
  role             = aws_iam_role.lambda_cdc_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
}

# 5. Event Source Mapping (Connects DynamoDB Stream -> Lambda)
resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  event_source_arn  = aws_dynamodb_table.orders_table.stream_arn
  function_name     = aws_lambda_function.cdc_processor.arn
  starting_position = "LATEST" # Process new changes as they happen
  batch_size        = 1
}

output "dynamodb_stream_arn" {
  value = aws_dynamodb_table.orders_table.stream_arn
}
