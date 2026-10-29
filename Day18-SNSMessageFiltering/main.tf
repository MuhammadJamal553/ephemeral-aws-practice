terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ========================================================
# 1. THE EVENT BUS INGESTION LAYER (CENTRAL SNS TOPIC)
# ========================================================

resource "aws_sns_topic" "event_bus" {
  name = "${var.project_name}-event-bus"
}

# ========================================================
# 2. THE DECOUPLED DOWNSTREAM PROCESSING TIERS (SQS QUEUES)
# ========================================================

# Queue A: Intended strictly for Critical System / Security Events
resource "aws_sqs_queue" "critical_queue" {
  name = "${var.project_name}-critical-queue"
}

# Queue B: Intended for General Metrics / Routine Logs
resource "aws_sqs_queue" "general_queue" {
  name = "${var.project_name}-general-queue"
}

# ========================================================
# 3. INTER-SERVICE SUBSCRIPTIONS WITH DYNAMIC JSON FILTERING
# ========================================================

# Subscription 1: Route messages to the Critical Queue ONLY if the event_type is "critical"
resource "aws_sns_topic_subscription" "critical_sub" {
  topic_arn = aws_sns_topic.event_bus.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.critical_queue.arn

  # CRUCIAL EXAM TASK: Message attribute structural filtering policy rule
  filter_policy = jsonencode({
    event_type = ["critical"]
  })
}

# Subscription 2: Route messages to the General Queue ONLY if the event_type is "standard"
resource "aws_sns_topic_subscription" "general_sub" {
  topic_arn = aws_sns_topic.event_bus.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.general_queue.arn

  filter_policy = jsonencode({
    event_type = ["standard"]
  })
}

# ========================================================
# 4. RESOURCE ACCESS ENVELOPE POLICIES (IAM PERMISSIONS WALL)
# ========================================================
# Amazon SNS needs explicit security rights to push message payloads into your SQS queues!

resource "aws_sqs_queue_policy" "critical_queue_policy" {
  queue_url = aws_sqs_queue.critical_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNSPublishToCriticalQueue"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.critical_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.event_bus.arn }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "general_queue_policy" {
  queue_url = aws_sqs_queue.general_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNSPublishToGeneralQueue"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.general_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.event_bus.arn }
      }
    }]
  })
}

# ========================================================
# 5. DATA LOG OUTPUTS FOR MONITORING VERIFICATION
# ========================================================

output "sns_topic_arn" {
  value       = aws_sns_topic.event_bus.arn
  description = "The central event broker address used to publish messaging payloads."
}

output "critical_queue_url" {
  value       = aws_sqs_queue.critical_queue.url
}

output "general_queue_url" {
  value       = aws_sqs_queue.general_queue.url
}
