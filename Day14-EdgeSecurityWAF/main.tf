terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

provider "aws"{
    region = var.aws_region
}

# ========================================================
# 1. PERIMETER SECURITY TIERS (AWS WAFv2 WEB ACL ARCHITECTURE)
# ========================================================

# Provision an AWS WAFv2 Web Access Control List (Web ACL)

resource "aws_wafv2_web_acl" "edge_waf" {
    name        = "${var.project_name}-web-acl"
    description = "Edge Perameter Firewall Protecting global CloudFront application Distribution"
    scope       = "CLOUDFRONT"

    default_action {
        allow {}  # Default posture: Allow traffic unless it explicitly trips a blocking rule rule parameters
    }

    # WAF Rule Layer: Automated IP Rate-Limiting Protection (Defends against spam bots & brute-force flooding)

    rule {
        name        = "IPRateLimitProtectionRule"
        priority    = 1

        action {
            block {} # Block the IP address if it crosses our threshold limits
        }

        statement {
            rate_based_statement {
                limit               = 100 # Maximum allowable connection requests per IP per 5-minute sliding window
                aggregate_key_type  = "IP"
            }
        }

        visibility_config {
            cloudwatch_metrics_enabled  = true
            metric_name                 = "IPrateLimitMetric"
            sampled_requests_enabled    = true
        }
    }
    visibility_config {
        cloudwatch_metrics_enabled  = true
        metric_name                 = "JamalEdgeWAMasterMatric"
        sampled_requests_enabled    = true
    }
}


# ========================================================
# 2. ORIGIN BACKEND ARCHITECTURE LAYER (PRIVATE S3 OBJECT STORAGE)
# ========================================================

resource "aws_s3_bucket" "secure_origin" {
    # lower() forces lowercase, replace() strips out accidental double hyphens
    bucket          = "jamal-secure-waf-origin-${var.project_name}-xxxx"  # Replace xxxx with unique numbers!
    force_destroy   = true
}

resource "aws_s3_bucket_public_access_block" "block_public" {
    bucket                  = aws_s3_bucket.secure_origin.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
    name                                = "${var.project_name}-oac"
    description                         = "Secure Edge Kry Protecting S3 backend acess lines."
    origin_access_control_origin_type   = "s3"
    signing_behavior                    = "always"
    signing_protocol                    = "sigv4"
}


# ========================================================
# 3. GLOBAL ROUTING ACCELERATION TIER (CLOUDFRONT ROUTED WITH WAF WALL)
# ========================================================

resource "aws_cloudfront_distribution" "cdn" {
    origin {
        domain_name                 = aws_s3_bucket.secure_origin.bucket_regional_domain_name
        origin_id                   = "S3-SecureWAFOrigin"
        origin_access_control_id    = aws_cloudfront_origin_access_control.s3_oac.id

    }
    enabled             = true
    is_ipv6_enabled     = true
    default_root_object = "index.html"


  # ==========================================
  # CRUCIAL EXAM FIREWALL ARRANGE LINKING
  # ==========================================
  web_acl_id    = aws_wafv2_web_acl.edge_waf.arn

  default_cache_behavior {
    allowed_methods     = ["GET", "HEAD"]
    cached_methods      = ["GET", "HEAD"]
    target_origin_id    = "S3-SecureWAFOrigin"

    forwarded_values {
        query_string= false
        cookies { forward = "none"}
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none"}
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ========================================================
# 4. SECURED RESOURCE CONTROL SYSTEM CONSTRAINTS
# ========================================================

resource "aws_s3_bucket_policy" "allow_cloudfront" {
    bucket      = aws_s3_bucket.secure_origin.id

    policy = jsonencode({
        Version     = "2012-10-17"
        Statement   = [{
            Sid         = "AllowCloudFrontPrincipalReadOnly"
            Effect      = "Allow"
            Principal   = { Service = "cloudfront.amazonaws.com" }
            Action      = "s3:GetObject"
            Resource    = "${aws_s3_bucket.secure_origin.arn}/*"
            Condition   = {
                StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn}
            }
        }]
    })
}

output "protected_cloudfront_url" {
    value       = "https://${aws_cloudfront_distribution.cdn.domain_name}"
    description = "The Global Secure Access Distribustion URL endpoint protected by AWS WAF"
}