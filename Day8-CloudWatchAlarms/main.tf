terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}
provider "aws" {
    region  = var.aws_region
}
# 1. Compress the Python monitoring application package automatically
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file = "lambda_function.py"
    output_path = "lambda_function.zip"
}

# 2. Build the Pub/Sub Messaging Topic for Operations Alerts
resource "aws_sns_topic" "ops_alerts" {
    name = "${var.project_name}-ops-alert"
}

resource "aws_sns_topic_subscription" "email_sub" {
    topic_arn   = aws_sns_topic.ops_alerts.arn
    protocol    = "email"
    endpoint    = var.alert_email
}

# 3. Create the Base Serverless Execution IAM Role
resource "aws_iam_role" "lambda_role" {
    name    = "${var.project_name}-lambda-role"

    assume_role_policy  = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Action      = "sts:AssumeRole"
            Effect      = "allow"
            Principal   = {Service : "lambda.amazonaws.com"}
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role        = aws_iam_role.lambda_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 4. Provision the Live Lambda Function Instance
resource "aws_lambda_function" "my_lambda" {
    filename       = data.archive_file.lambda_zip.output_path
    function_name   = "${var.project_name}-function"
    role            = aws_iam_role.lambda_role.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash= data.archive_file.lambda_zip.output_base64sha256
    runtime         = "python3.12"
}

# 5. Spin up the Public HTTP Routing API Gateway front door
resource "aws_apigatewayv2_api" "http_api" {
    name            = "${var.project_name}-api"
    protocol_type   = "HTTP"
}

resource "aws_apigatewayv2_integration" "link" {
    api_id          = aws_apigatewayv2_api.http_api.id
    integration_type= "AWS_PROXY"
    integration_uri = aws_lambda_function.my_lambda.arn
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

# ========================================================
# 6. CLOUDWATCH AUTOMATED MONITORING LAYER (THE EXAM CORE)
# ========================================================

# Provision an automated Metric Alarm targeting our function's metrics stream
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
    alarm_name          = "${var.project_name}-error-tripwire"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods  = 1
    metric_name         = "Errors" # Native AWS CloudWatch system metric name
    namespace           = "AWS/Lambda"
    period              = 60 # Check the data metrics log loop window every 60 seconds
    statistic           = "Sum"
    threshold           = 1 # Trip the alarm instantly if 1 or more errors execute
    alarm_description   = "This Alarm Monitors Serverless function Error Rate Automatically"

    # Action Binding: Pass the alert down to our SNS Pub/Sub messaging bus topic if tripped!
    alarm_actions       = [aws_sns_topic.ops_alerts.arn]
} 

output "api_testing_endpoint" {
    value   = aws_apigatewayv2_stage.stage.invoke_url
}
