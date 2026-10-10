    terraform{
        required_providers{
            aws = {
                source = "hashicorp/aws"
                version = "~> 5.0"
            }
        }
    }

    provider "aws"{
        region = "us-east-1"
    }


    resource "aws_s3_bucket" "my_s3_bucket"{
        bucket = "jamalkhan-marathon-practice-day1-2235"
    }

    resource "aws_s3_bucket_public_access_block" "block_puclic"{
        bucket                  = aws_s3_bucket.my_s3_bucket.id
        block_public_acls       = true
        block_public_policy     = true
        ignore_public_acls      = true
        restrict_public_buckets  = true
    }
