terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version  = "~>5.0"
        }
    }
}
# 1. Compress the Python secure backend package automatically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}
# 2. Provision a Standard String Parameter inside Systems Manager Parameter Store
resource "aws_ssm_parameter" "app_config" {
  name        = "/config/${var.project_name}/welcome_message"
  type        = "SecureString" # Encrypted string type baseline
  value       = "ProductionKey-9988X-SecureAccessGranted"
  description = "Decoupled enterprise credential configuration environment variable"
}

# 3. Create the Execution IAM Role for the Lambda Engine
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"


  assume_role_policy  = jsonencode ({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {Service = "lambda.amazonaws.com"}
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role        = aws_iam_role.lambda_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 4. CRUCIAL EXAM TASK: Principle of Least Privilege SSM Access Policy
# This ensures our Lambda function can ONLY read your specific SSM parameter path!
resource "aws_iam_role_policy" "lambda_ssm_read" {
  name    = "lambda_ssm_secure_read_policy"
  role    = aws_iam_role.lambda_role.id

  policy  = jsonencode ({
    Version   = "2012-10-17"
    Statement = [{
      Sid   = "AllowSSMParameterAccess"
      Effect= "Allow"
      Action= [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = aws_ssm_parameter.app_config.arn # Tight parameter resource constraint!
    }]
  })
}

# 5. Provision the Lambda Function injecting the target parameter path variable
resource "aws_lambda_function" "my_lambda" {
  filename        = data.archive_file.lambda_zip.output_path
  function_name   = "${var.project_name}-function"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash= data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.12"


  environment {
    variables = {
      CONFIG_PARAM_PATH = aws_ssm_parameter.app_config.name
    }
  }
}

# 6. Spin up the Public HTTP Routing API Gateway front door
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "link" {
  api_id          = aws_apigatewayv2_api.http_api.id
  integration_type= "AWS_PROXY"
  integration_uri = aws_lambda_function.my_lambda.arn
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.link.id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
} 

resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "secure_api_endpoint" {
  value   = aws_apigatewayv2_stage.stage.invoke_url
}