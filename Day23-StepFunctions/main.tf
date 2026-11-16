provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "day23_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_lambda_function" "process_step" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "day23-workflow-processor"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
}

resource "aws_iam_role" "iam_for_sfn" {
  name = "day23_sfn_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "sfn_lambda_invoke" {
  name = "day23_sfn_invoke_lambda"
  role = aws_iam_role.iam_for_sfn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.process_step.arn
    }]
  })
}

resource "aws_sfn_state_machine" "order_workflow" {
  name     = "day23-validation-workflow"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = jsonencode({
    Comment = "SAA-C03 Step Functions State Machine"
    StartAt = "ValidatePayload"
    States = {
      ValidatePayload = {
        Type     = "Task"
        Resource = aws_lambda_function.process_step.arn
        End      = true
      }
    }
  })
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.order_workflow.arn
}
