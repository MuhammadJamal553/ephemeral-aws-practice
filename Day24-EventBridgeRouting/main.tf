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

resource "aws_iam_role" "lambda_role" {
  name = "day24_eventbridge_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_lambda_function" "order_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "day24-high-value-order-handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
}

# 1. Create a Custom EventBridge Event Bus
resource "aws_cloudwatch_event_bus" "custom_bus" {
  name = "day24-orders-event-bus"
}

# 2. Create an EventBridge Rule with Content-Based JSON Filtering
resource "aws_cloudwatch_event_rule" "high_value_order_rule" {
  name           = "day24-high-value-order-rule"
  description    = "Captures orders with amount greater than or equal to 500"
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name

  event_pattern = jsonencode({
    source      = ["custom.orders"]
    detail-type = ["OrderPlaced"]
    detail = {
      amount = [{ numeric = [">=", 500] }]
    }
  })
}

# 3. Connect the Rule to the Lambda Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule           = aws_cloudwatch_event_rule.high_value_order_rule.name
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name
  target_id      = "SendToLambda"
  arn            = aws_lambda_function.order_handler.arn
}

# 4. Grant EventBridge Permission to Invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.high_value_order_rule.arn
}

output "custom_bus_name" {
  value = aws_cloudwatch_event_bus.custom_bus.name
}

