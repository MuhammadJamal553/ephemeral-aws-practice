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

# Automatically package the Python worker script
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# ========================================================
# 1. FAULT-TOLERANT MESSAGING TIER (SQS MAIN QUEUE & DLQ)
# ========================================================

# Provision the Dead-Letter Queue (The isolation quarantine vault)
resource "aws_sqs_queue" "dlq_queue" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600 # Store bad messages safely for up to 14 days for inspection
}

# Provision the Primary Processing SQS Queue
resource "aws_sqs_queue" "main_queue" {
  name                      = "${var.project_name}-main-queue"
  delay_seconds             = 0
  max_message_size          = 262144 # 256 KB standard limits
  message_retention_seconds = 86400  # 1 day storage cycle
  receive_wait_time_seconds = 0      # Short polling baseline

  # CRUCIAL EXAM TASK: Bind the DLQ tripwire rules via a redrive policy
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_queue.arn
    maxReceiveCount     = 3 # If a message fails execution 3 times, send it to the DLQ automatically!
  })
}

# ========================================================
# 2. CONSUMER LAYER (SERVERLESS LAMBDA ENGINE & SECURITY)
# ========================================================

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-sqs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Grant Lambda explicit permissions to pull messages from SQS
resource "aws_iam_role_policy" "lambda_sqs_permissions" {
  name = "lambda_sqs_read_delete_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowSQSReadOperations"
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.main_queue.arn
    }]
  })
}

resource "aws_lambda_function" "queue_worker" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-worker"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
}

# ========================================================
# 3. INTER-SERVICE EVENT LINKING (SQS AS A TRIGGER)
# ========================================================

# Wire up SQS to automatically feed messages into our Lambda function
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main_queue.arn
  function_name    = aws_lambda_function.queue_worker.arn
  batch_size       = 1 # Process one message at a time to test fallback limits accurately
}

# ========================================================
# 4. DATA LOG OUTPUTS FOR MONITORING
# ========================================================

output "primary_queue_url" {
  value       = aws_sqs_queue.main_queue.url
  description = "The target endpoint URL used to inject messages into the main pipeline."
}
