terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~>6.0"
        }
    }
}



provider "aws"{
    region = var.aws_region
}


# Automatically extract your 12-digit AWS Account ID dynamically to prevent hardco
data "aws_caller_identity" "current" {}

# 1. Compress the Python token application package automatically
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file = "lambda_function.py"
    output_path = "lambda_function.zip"
}

# ========================================================
# 2. TARGET ISOLATED INFRASTRUCTURE LAYER (SIMULATING PRODUCTION)
# ========================================================

# Create a secure isolated target bucket (S3 names must be globally unique!)
resource  "aws_s3_bucket" "secure_target" {
    bucket          = "jamal-secure-day10-${data.aws_caller_identity.current.account_id}"
    force_destroy   = true # Allows clean destruction loop tearing down objects safely
}

# Create the Target Role with an explicit Trust Policy allowing the Lambda Role to assume it
resource "aws_iam_role" "target_assume_role" {
    name = "${var.project_name}-target-assume-role"

    assume_role_policy  = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Sid         = "AllowLambdaRoleToAssumeThisRole"
            Effect      = "Allow"
            Principal   = {
                # Strict security constraint: Only allow identities inside this account running our explicit Lambda role path to assume this
                AWS = aws_iam_role.base_lambda_role.arn
            }
            Action = "sts:AssumeRole"
        }]
    })
}

# Attach an access policy to the assumed role granting it explicit access to read our secure target storage bucket
resource "aws_iam_role_policy" "target_s3_access" {
    name    = "target_s3_read_policy"
    role    = aws_iam_role.target_assume_role.id

    policy = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Sid     = "AllowS3ReadOperations"
            Effect  = "Allow"
            Action  = [
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:GetObject"
            ]
            Resource = [
                aws_s3_bucket.secure_target.arn,
                "${aws_s3_bucket.secure_target.arn}/*"
            ]
        }]
    })
}

# ========================================================
# 3. BASE SERVERLESS INFRASTRUCTURE LAYER (SIMULATING DEVELOPMENT)
# ========================================================

# Create the standard base computing execution identity role
resource "aws_iam_role" "base_lambda_role" {
    name    = "${var.project_name}-base-lambda-role"


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
    role        = aws_iam_role.base_lambda_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CRUCIAL EXAM TASK: Least Privilege STS Access Boundary Policy
# This explicitly authorizes our base function identity to perform the assume role action ONLY on our specific target role ARN!
resource "aws_iam_role_policy" "lambda_sts_assume" {
    name    = "lambda_sts_assume_policy"
    role    = aws_iam_role.base_lambda_role.id


    policy  = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Sid         = "AllowSTSSpecificAssumeRole"
            Effect      = "Allow"
            Action      = "sts:AssumeRole"
            Resource    = aws_iam_role.target_assume_role.arn # Lock down the target execution boundary string
        }]
    })
}

# Provision the functional Lambda computing element mapping deployment environments
resource "aws_lambda_function" "my_lambda" {
    filename        = data.archive_file.lambda_zip.output_path
    function_name   = "${var.project_name}-engine"
    role            = aws_iam_role.base_lambda_role.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash= data.archive_file.lambda_zip.output_base64sha256
    runtime         = "python3.12"

    environment {
        variables = {
            TARGET_ROLE_ARN     = aws_iam_role.target_assume_role.arn
            TARGET_BUCKET_NAME  = aws_s3_bucket.secure_target.id
        }
    }
}

# ========================================================
# 4. ROUTING & GATEWAY NETWORKING PIPELINES
# ========================================================

resource "aws_apigatewayv2_api" "http_api" {
    name            = "${var.project_name}-api"
    protocol_type   = "HTTP"
}

resource "aws_apigatewayv2_integration" "link" {
    api_id          = aws_apigatewayv2_api.http_api.id
    integration_type= "AWS_PROXY"
    integration_uri= aws_lambda_function.my_lambda.arn
}

resource "aws_apigatewayv2_route" "route" {
    api_id      = aws_apigatewayv2_api.http_api.id
    route_key   = "ANY /"
    target      = "integrations/${aws_apigatewayv2_integration.link.id}"
}
resource "aws_apigatewayv2_stage" "stage" {
    api_id      = aws_apigatewayv2_api.http_api.id
    name        = "$default"
    auto_deploy = true
}
resource "aws_lambda_permission" "allow_api" {
    statement_id    = "AllowExecutionFromAPIGateway"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.my_lambda.function_name
    principal       = "apigateway.amazonaws.com"
    source_arn      = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "delegation_api_endpoint" {
    value       = aws_apigatewayv2_stage.stage.invoke_url
    description = "The Dynamic Routing Endpoint to verify your temprory cryptographic role delegation loop. "
}