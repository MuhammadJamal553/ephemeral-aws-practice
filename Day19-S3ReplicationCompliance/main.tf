terraform{
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

# Primary Region Configuration
provider "aws" {
    region  = var.primary_region
}


# Alternate Replica Region Configuration via Alias
provider "aws" {
    region  = var.replica_region
    alias   = "replica_zone"
}

data "aws_caller_identity" "current" {}

# ========================================================
# 1. DESTINATION ENVIRONMENT REPLICA TIER (US-WEST-2)
# ========================================================

# The replica destination bucket MUST have versioning enabled to receive CRR streams
resource "aws_s3_bucket" "replica_bucket" {
  provider = aws.replica_zone
  bucket   = "jamal-compliance-replica-${data.aws_caller_identity.current.account_id}"
  
  # Crucial Exam Step: Enforce explicit Object Lock hooks at resource birth
  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "replica_versioning" {
  provider = aws.replica_zone
  bucket   = aws_s3_bucket.replica_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ========================================================
# 2. SECURITY ASSIGNMENT LAYER (IAM REPLICATION IDENTITY)
# ========================================================

resource "aws_iam_role" "replication_role" {
  name = "${var.project_name}-s3-crr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
    }]
  })
}

# Grant the S3 replication process rights to pull objects out of Source and deposit to Destination
resource "aws_iam_role_policy" "replication_policy" {
  name = "s3-crr-execution-policy"
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.source_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectRetention" # 👈(Allows reading lock status from source)
        ]
        Resource = "${aws_s3_bucket.source_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ReplicateObjectLock" # 👈(Allows writing lock status to replica)
        ]
        Resource = "${aws_s3_bucket.replica_bucket.arn}/*"
      }
    ]
  })
}

# ========================================================
# 3. SOURCE INFRASTRUCTURE TIER WITH COMPLIANCE WORM (US-EAST-1)
# ========================================================

resource "aws_s3_bucket" "source_bucket" {
  bucket              = "jamal-compliance-source-${data.aws_caller_identity.current.account_id}"
  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "source_versioning" {
  bucket = aws_s3_bucket.source_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure strict Compliance Mode WORM protections at the bucket blueprint boundary level
resource "aws_s3_bucket_object_lock_configuration" "worm_lock" {
  bucket = aws_s3_bucket.source_bucket.id

  rule {
    default_retention {
      mode = "COMPLIANCE" # Rigid Compliance Mode! Blocks all modification/deletion paths.
      days = 1
    }
  }
  depends_on = [aws_s3_bucket_versioning.source_versioning]
}

# Establish Cross-Region Replication Mapping Rules
resource "aws_s3_bucket_replication_configuration" "crr" {
  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.source_bucket.id

  rule {
    id     = "GlobalBackupStream"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica_bucket.arn
      storage_class = "STANDARD"
    }
  }
  depends_on = [aws_s3_bucket_versioning.source_versioning]
}

# ========================================================
# 4. DATA METRICS MONITORING VERIFICATION OUTLINES
# ========================================================

output "source_bucket_name" {
  value = aws_s3_bucket.source_bucket.id
}

output "replica_bucket_name" {
  value = aws_s3_bucket.replica_bucket.id
}