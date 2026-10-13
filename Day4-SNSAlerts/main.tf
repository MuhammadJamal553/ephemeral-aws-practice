terraform{
    required_providers{
        aws={
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws"{
    region = "us-east-1"
}

# 1. Automatically pack the Python alert code package
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file = "lambda_function.py"
    output_path = "lambda_function.zip"
}

# 2. Build the SNS Pub/Sub Messaging Topic
resource "aws_sns_topic" "visitor_alerts" {
    name = "jamal_khan-marathon-visitor-alerts-Day4"
}

# 3. Create your secure email subscriber pipeline
# WARNING: Replace your-email@example.com with your actual personal email address!

resource "aws_sns_topic_subscription" "email_sub" {
    topic_arn   = aws_sns_topic.visitor_alerts.arn
    protocol    = "email"
    endpoint    = "jamalkhan277442@gmail.com"
}

# 4. Create the Execution IAM Role for your Serverless Engine
resource "aws_iam_role" "lambda_role" {
    name = "jamalkhan_marathon-lambda_role_Day4"

    assume_role_policy = jsonencode({
        Version     = "2012-10-17"
        Statement   = [{
            Action      = "sts:AssumeRole"
            Effect      = "Allow"
            Principal   = { Service = "lambda.amazonaws.com"}
        }]
    })        
}
# 5. Attach core CloudWatch internal execution logging monitoring rights
resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role        = aws_iam_role.lambda_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# 6. CRUCIAL EXAM TASK: Principle of Least Privilege Inline IAM Access Policy
# This ensures our Lambda function can ONLY publish into our specific SNS topic ARN!
resource "aws_iam_role_policy" "lambda_sns_publish"{
    name = "lambda_sns_publish_policy"
    role = aws_iam_role.lambda_role.id

    policy = jsonencode({
        Version     = "2012-10-17"
        Statement   = [{
            Sid     = "AllowPublishToSpecificSNSTopic"
            Effect  = "Allow"
            Action  = "sns:Publish"
            Resource = aws_sns_topic.visitor_alerts.arn # Strict resource filtering! No '*' allowed.
        }]
    })
}

# 7. Provision your Lambda Function with integrated environment mapping
resource "aws_lambda_function" "my_lambda" {
    filename            = data.archive_file.lambda_zip.output_path
    function_name       = "jamal_khan_resume_backend_Day4"
    role                = aws_iam_role.lambda_role.arn
    handler             = "lambda_function.lambda_handler"
    source_code_hash    = data.archive_file.lambda_zip.output_base64sha256
    runtime             = "python3.12"

    # Pass the live AWS infrastructure ARN directly into our Python script environment securely
    environment {
        variables = {
            SNS_TOPIC_ARN = aws_sns_topic.visitor_alerts.arn
        }
    }
}

# 8. Spin up the Public HTTP API Routing Gateway front door
resource "aws_apigatewayv2_api" "http_api"{
    name            = "jamal_khan_portfolio_api_day4"
    protocol_type   = "HTTP"
}

# 9. Bridge your public API path to your Function instance
resource "aws_apigatewayv2_integration" "api_lambda_link" {
    api_id              = aws_apigatewayv2_api.http_api.id
    integration_type    = "AWS_PROXY"
    integration_uri     = aws_lambda_function.my_lambda.arn
}

# 10. Map listener URL routing patterns
resource "aws_apigatewayv2_route" "api_route" {
    api_id      = aws_apigatewayv2_api.http_api.id
    route_key   = "ANY /"
    target      = "integrations/${aws_apigatewayv2_integration.api_lambda_link.id}"
}

# 11. Create automatic deployment stages
resource "aws_apigatewayv2_stage" "api_stage" {
    api_id      = aws_apigatewayv2_api.http_api.id
    name        = "$default"
    auto_deploy = true
}

# 12. Security configuration parameter mapping
resource "aws_lambda_permission" "allow_api" {
    statement_id    = "AllowExeccutionFromApiGatway"
    action          = "lambda:InvokeFuntion"
    function_name   = aws_lambda_function.my_lambda.function_name
    principal       = "apigateway.amazonaws.com"
    source_arn      = "${aws_apigatewayv2_api.http_api.execution_arn}"
}

# 13. Print out your unique public backend link endpoint
output "api_enpoint" {
    value = aws_apigatewayv2_stage.api_stage.invoke_url
}