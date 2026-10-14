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

# ==========================================
# 1. FRONTEND INFRASTRUCTURE (STORAGE & CDN)
# ==========================================

resource "aws_s3_bucket" "frontend_bucket" {
    bucket = "jamal-khan-converged-portfolio-553-542" # Replace with unique numbers!
}

resource "aws_s3_bucket_public_access_block" "block_public"{
    bucket                  = aws_s3_bucket.frontend_bucket.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# Upload your index.html file to S3 automatically with matching HTML header constraints
resource "aws_s3_object" "index" {
    bucket      = aws_s3_bucket.frontend_bucket.id
    key         = "index.html"
    source      = "index.html"
    content_type= "text/html"
}

resource "aws_cloudfront_origin_access_control" "oac"{
    name                                = "jamal-khan-converged-oac"
    description                         = "Secure CloudFront access principal rules to S3 origin"
    origin_access_control_origin_type   = "s3"
    signing_behavior                    = "always"
    signing_protocol                    = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
    origin{
        domain_name             = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
        origin_id               = "S3-FrontendOrigin"
        origin_access_control_id= aws_cloudfront_origin_access_control.oac.id
    }
    enabled             = true
    is_ipv6_enabled     = true
    default_root_object = "index.html"


    default_cache_behavior {
        allowed_methods = ["GET","HEAD"]
        cached_methods  = ["GET","HEAD"]
        target_origin_id= "S3-FrontendOrigin"

        forwarded_values {
            query_string = false
            cookies {forward="none"}   
        }
        viewer_protocol_policy  = "redirect-to-https"
        min_ttl                 = 0
        default_ttl             = 3600
        max_ttl                  = 86400
    }

    restrictions {
        geo_restriction { restriction_type = "none"}
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}


resource "aws_s3_bucket_policy" "allow_cloudfront" {
    bucket  = aws_s3_bucket.frontend_bucket.id

    policy  = jsonencode({
        Version     = "2012-10-17"
        Statement   = [{
            Sid         = "AllowCloudFrontServiceReadOnly"
            Effect      = "Allow"
            Principal   = {Service = "cloudfront.amazonaws.com"}
            Action      = "s3:GetObject"
            Resource    = "${aws_s3_bucket.frontend_bucket.arn}/*"
            Condition   ={
                StringEquals = {"AWS:Source_Arn"= aws_cloudfront_distribution.cdn.arn}
            }
        }]
    })
}

# ==========================================
# 2. BACKEND INFRASTRUCTURE (SERVERLESS & SNS)
# ==========================================

data "archive_file" "lambda_zip"{
    type         = "zip"
    source_file  = "lambda_function.py"
    output_path  = "lambda_function.zip"
}

resource "aws_sns_topic" "alerts"{
    name = "jamal-khan-converged-alerts-Day5"
}

resource "aws_sns_topic_subscription" "email" {
    topic_arn   = aws_sns_topic.alerts.arn
    protocol    = "email"
    endpoint    = "jamalkhan277442@gmail.com" # <-- Put your real email here!
}

resource "aws_iam_role" "lambda_role" {
    name = "Jamal_khan_converged_lambda_role"

    assume_role_policy  = jsonencode ({
        Version  ="2012-10-17"
        Statement =[{
            Action      = "sts:AssumeRole"
            Effect      = "Allow"
            Principal   = {Service = "lambda.amazonaws.com"}
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role        = aws_iam_role.lambda_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sns"{
    name    = "lambda_sns_publish_policy"
    role    = aws_iam_role.lambda_role.id

    policy = jsonencode({
        Version     = "2012-10-17"
        Statement   = [{
            Sid         = "AllowSNSPublish"
            Effect      = "Allow"
            Action      = "sns:Publish"
            Resource    = aws_sns_topic.alerts.arn 
        }]
    })
}

resource "aws_lambda_function" "my_lambda" {
    filename        = data.archive_file.lambda_zip.output_path
    function_name   = "jmala-khan-converged-backend"
    role            = aws_iam_role.lambda_role.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash= data.archive_file.lambda_zip.output_base64sha256
    runtime         = "python3.12"

    environment {
        variables = {SNS_TOPIC_ARN = aws_sns_topic.alerts.arn}
    }
}

resource "aws_apigatewayv2_api" "http_api" {
    name            = "jamal-khan-converged-api"
    protocol_type   = "HTTP"
}

resource "aws_apigatewayv2_integration" "link"{
    api_id          = aws_apigatewayv2_api.http_api.id
    integration_type= "AWS_PROXY"
    integration_uri = aws_lambda_function.my_lambda.arn
}

resource "aws_apigatewayv2_stage" "stage" {
    api_id      = aws_apigatewayv2_api.http_api.id
    name        = "$default"
    auto_deploy = true
}

resource "aws_lambda_permission" "allow_api" {
    statement_id    = "AllowExecutionFromApiGatway"
    action          = "lambda:InvokeFuntion"
    function_name   = aws_lambda_function.my_lambda.function_name
    principal       = "apigateway.amazonaws.com"
    source_arn      = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# ==========================================
# 3. INTERACTIVE SYSTEM TERMINAL OUTPUTS
# ==========================================

output "cloudfront_url" {
    value = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "api_enpoint" {
    value   = aws_apigatewayv2_stage.stage.invoke_url
}