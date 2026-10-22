terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}
# ========================================================
# PRIMARY GEOGRAPHIC REGION PROVIDER SETUP (US-EAST-1)
# ========================================================

provider "aws" {
    region  = var.primary_region
}
# ========================================================
# SECONDARY GEOGRAPHIC REGION PROVIDER SETUP (US-WEST-2)
# ========================================================
provider "aws" {
    region  = var.secondary_region
    alias   = "west_coast" # The alias keyword tells Terraform this is an alternate provider profile!
}

# Automatically package the Python logic script
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file = "lambda_function.py"
    output_path = "lambda_function.zip"
}

# ========================================================
# 1. PRIMARY REGION BLOCK ARRANGEMENTS (US-EAST-1)
# ========================================================
resource "aws_iam_role" "lambda_role" {
    name    = "${var.project_name}-lambda-global-role"


    assume_role_policy = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Action      = "sts:AssumeRole"
            Effect      = "Allow"
            Principal   = {Service = "lambda.amazonaws.com"}
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role          = aws_iam_role.lambda_role.name
    policy_arn    = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "primary_lambda" {
    filename       = data.archive_file.lambda_zip.output_path
    function_name   = "${var.project_name}-primary-engine"
    role            = aws_iam_role.lambda_role.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash= data.archive_file.lambda_zip.output_base64sha256
    runtime         = "python3.12"
}

resource "aws_apigatewayv2_api" "primary_api" {
    name            = "${var.project_name}-primary-api"
    protocol_type   = "HTTP"
}

resource "aws_apigatewayv2_integration" "primary_link" {
    api_id          = aws_apigatewayv2_api.primary_api.id
    integration_type= "AWS_PROXY"
    integration_uri = aws_lambda_function.primary_lambda.arn
}

resource "aws_apigatewayv2_route" "primary_route" {
    api_id      = aws_apigatewayv2_api.primary_api.id
    route_key   = "ANY /"
    target      = "integrations/${aws_apigatewayv2_integration.primary_link.id}"
}
resource "aws_apigatewayv2_stage" "primary_stage" {
    api_id      = aws_apigatewayv2_api.primary_api.id
    name        = "$default"
    auto_deploy = true
}

resource "aws_lambda_permission" "allow_primary_api" {
    statement_id    = "AllowExecutionFromAPIGateway"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.primary_lambda.function_name
    principal       = "apigateway.amazonaws.com"
    source_arn      = "${aws_apigatewayv2_api.primary_api.execution_arn}/*/*"
}


# ========================================================
# 2. SECONDARY REGION BLOCK ARRANGEMENTS (US-WEST-2)
# ========================================================

# Notice the explicit use of provider = aws.west_coast to force these resources to deploy out west!
resource "aws_lambda_function" "secondary_lambda" {
    provider        = aws.west_coast
    filename        = data.archive_file.lambda_zip.output_path
    function_name   = "${var.project_name}-secondary-engine"
    role            = aws_iam_role.lambda_role.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash= data.archive_file.lambda_zip.output_base64sha256
    runtime         = "python3.12"
}

resource "aws_apigatewayv2_api" "secondary_api" {
    provider        = aws.west_coast
    name            = "${var.project_name}-secondary-api"
    protocol_type   = "HTTP"
}

resource "aws_apigatewayv2_integration" "secondary_link" {
    provider        = aws.west_coast
    api_id          = aws_apigatewayv2_api.secondary_api.id
    integration_type= "AWS_PROXY"
    integration_uri = aws_lambda_function.secondary_lambda.arn
}

resource "aws_apigatewayv2_route" "seocondary_route" {
    provider        = aws.west_coast
    api_id          = aws_apigatewayv2_api.secondary_api.id
    route_key       = "ANY /"
    target          =  "integrations/${aws_apigatewayv2_integration.secondary_link.id}"
}

resource "aws_apigatewayv2_stage" "secondary_stage" {
    provider    = aws.west_coast
    api_id      = aws_apigatewayv2_api.secondary_api.id
    name        = "$default"
    auto_deploy = true
}

resource "aws_lambda_permission" "allow_secondary_api" {
    provider        = aws.west_coast
    statement_id    = "AllowExecutionFromAPIGateway"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.secondary_lambda.function_name
    principal       = "apigateway.amazonaws.com"
    source_arn      = "${aws_apigatewayv2_api.secondary_api.execution_arn}/*/*"
}

# ========================================================
# 3. MONITORING VERIFICATION ENDPOINT OUTPUTS
# ========================================================

output "primary_east_coast_endpoint" {
    value       = aws_apigatewayv2_stage.primary_stage.invoke_url
    description = "The Direct address to hit your US-East-1 Configuration Infrastructure"
}

output "secondary_west_coast_endpoint" {
    value       = aws_apigatewayv2_stage.secondary_stage.invoke_url
    description = "The Direct address to hit your US-west-2 Configuration Infrastructure"
}