terraform{
    required_providers{
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}
# 1. Configure the AWS Provider
provider "aws" {
    region = "us-east-1"
}
# 2. Define the Private S3 Bucket (The Origin)
resource "aws_s3_bucket" "my_private_bucket" {
    bucket = "jamalkhan-marathon-bucket-day2-542"
}
# 3. Block All Public Access to the Bucket
resource "aws_s3_bucket_public_access_block" "block_public"{
    bucket                  = aws_s3_bucket.my_private_bucket.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# 4. Create the CloudFront Origin Access Control (OAC)
# This acts as the secure "key" that allows CloudFront to read from your private S3 bucket
resource "aws_cloudfront_origin_access_control" "s3_oac"{
    name                                = "s3_porrtfolio_oac_day2"
    description                         = "OAC for Private S3 Portfolio Access"
    origin_access_control_origin_type   = "s3"
    signing_behavior                    = "always"
    signing_protocol                   = "sigv4"
}

# 5. Create the CloudFront Distribution (The Edge Global Layer)
resource "aws_cloudfront_distribution" "cdn" {
    origin{
        domain_name                 = aws_s3_bucket.my_private_bucket.bucket_regional_domain_name
        origin_id                   = "S3-PortfolioOrigin"
        origin_access_control_id    = aws_cloudfront_origin_access_control.s3_oac.id
    }
    enabled                 = true
    is_ipv6_enabled         = true
    default_root_object     = "index.html"

    default_cache_behavior  {
        allowed_methods      = ["GET", "HEAD"]
        cached_methods       = ["GET", "HEAD"]
        target_origin_id    = "S3-PortfolioOrigin"

        forwarded_values  {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "redirect-to-https" # Exam concept: Enforcing HTTPS encryption
        min_ttl         = 0
        default_ttl     = 3600
        max_ttl         = 86400
    }
    restrictions{
        geo_restriction {
            restriction_type    = "none"
        }
    }
    viewer_certificate {
        cloudfront_default_certificate= true
    }
}
# 6. S3 Bucket Policy (Allows ONLY your CloudFront Distribution to read files)
resource "aws_s3_bucket_policy" "allow_cloudfront" {
    bucket      = aws_s3_bucket.my_private_bucket.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid         = "AllowCloudFrontServicePrincipalReadOnly"
                Effect      = "Allow"
                Principal   = {
                    Service = "cloudfront.amazonaws.com"
                }
                Action      =   "s3:GetObject"
                Resource    = "${aws_s3_bucket.my_private_bucket.arn}/*"
                Condition   ={
                    StringEquals = {
                        "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
                    }
                }
            }
        ]
    })
}
