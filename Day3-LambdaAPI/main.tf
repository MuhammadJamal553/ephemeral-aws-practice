terraform{
    required_providers{
        aws ={
            source = "hashicorp/aws"
            version= "~> 5.0"
        }
    }
}

provider "aws"{
    region = "us-east-1"
}

# 1. Automatically zip the Python file (AWS Lambda requires code packages to be zipped)
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file = "lambda_function.py"
    output_path = "lambda_function.zip"
}

# 2. Build the Execution IAM Role for the Lambda Function

resource "aws_iam_role" "lambda_role" {
    name = "jamal_khan_marathon_lambda_role_day3"

    assume_role_policy = jsonencode ({
        Version     = "2012-10-17"
        Statement   =[{
            Action      = "sts:AssumeRole"
            Effect      = "Allow"
            Principal   = { Service = "lambda.amazonaws.com"}
        }]
    }) 
}

# 3. Attach standard CloudWatch logging permissions (Exam Blueprint Standard for monitoring)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role        = aws_iam_role.lambda_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

}

# 4. Provision the Live Lambda Function
resource "aws_lambda_function" "my_lambda" {
    filename       = data.archive_file.lambda_zip.output_path
    function_name   = "jamal-resume-backend-day3"
    role            = aws_iam_role.lambda_role.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash= data.archive_file.lambda_zip.output_base64sha256
    runtime         = "python3.12"
}

# 5. Spin up the HTTP API Gateway (The public routing front door)
resource "aws_apigatewayv2_api" "http_api" {
    name            = "jamal_khan_portfolio_api_day3"
    protocol_type   = "HTTP"
}


# 6. Bridge the API Gateway path directly to the Lambda function

resource "aws_apigatewayv2_integration" "api_lambda_link" {
    api_id              = aws_apigatewayv2_api.http_api.id
    integration_type    = "AWS_PROXY"
    integration_uri     = aws_lambda_function.my_lambda.arn
}

# 7. Map the URL listener routing patterns (Any request triggers our integration)
resource "aws_apigatewayv2_route" "api_route" {
    api_id      = aws_apigatewayv2_api.http_api.id
    route_key   = "ANY /"
    target      = "integrations/${aws_apigatewayv2_integration.api_lambda_link.id}"
}

# 8. Create a default stage deployment so changes are live instantly

resource "aws_apigatewayv2_stage" "api_stage" {
    api_id      = aws_apigatewayv2_api.http_api.id
    name        = "$default"
    auto_deploy = true
}

# 9. Grant API Gateway permission to trigger your Lambda (Security Firewall)
resource "aws_lambda_permission" "allow_api" {
    statement_id    = "AllowExeccutionFromApiGatway"
    action          = "lambda:InvokeFuntion"
    function_name    = aws_lambda_function.my_lambda.function_name
    principal       = "apigateway.amazonaws.com"
    source_arn      = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# 10. Print the unique live API URL directly to the terminal when complete

output "api_enpoint"{
    value = aws_apigatewayv2_stage.api_stage.invoke_url
}
