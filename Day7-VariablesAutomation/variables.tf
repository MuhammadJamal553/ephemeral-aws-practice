terraform{
    required_providers{
        aws={
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

variable "aws_region"{
    type        = string
    default     = "us-east-1"
    description = "The target AWS Geopraphic Deployment Region boundry"
}

variable "project_name" {
    type        = string
    default     = "jamal-marathon-day7"
    description = "The core Suffix Identifier string used accross resources"
}


variable "environment" {
    type        = string
    default     = "dev"
    description = "The runtime phase tagging parameter for isolation constraint."
}