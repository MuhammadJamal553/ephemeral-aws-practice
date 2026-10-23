variable "aws_region" {
    type    = string
    default = "us-east-1" # CRUCIAL: CloudFront-integrated WAF Web ACLs MUST be deployed in us-east-1!
}

variable "project_name" {
    type    = string
    default = "jamal-khan-marathon-day14-"
}