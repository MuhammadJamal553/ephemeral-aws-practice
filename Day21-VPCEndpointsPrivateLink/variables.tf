variable "primary_region" {
    type    = string
    default = "us-east-1"
}

variable "project_name" {
    type    = string
    default = "jamal-khan-marathon-day21"
}


variable "vpc_cidr" {
    type    = string
    default = "10.50.0.0/16"
}


variable "lock_bucket_to_endpoint" {
    type    = bool
    default = false
}