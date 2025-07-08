# modules/sqs/main.tf

# Main SQS queue
resource "aws_sqs_queue" "main" {
  name = "${var.project_tag}-${var.environment}-${var.queue_name}"

  # Message retention and processing settings
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  
  # Dead letter queue configuration
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${var.queue_name}"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "message-queue"
  }
}

# Dead Letter Queue (optional)
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0
  
  name = "${var.project_tag}-${var.environment}-${var.queue_name}-dlq"
  
  # DLQ typically has longer retention
  message_retention_seconds = var.dlq_message_retention_seconds

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${var.queue_name}-dlq"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "dead-letter-queue"
  }
}

# IAM policy for backend (producer) access
resource "aws_iam_policy" "backend_sqs_access" {
  name        = "${var.project_tag}-${var.environment}-backend-sqs-access"
  description = "IAM policy for backend to send messages to SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-backend-sqs-policy"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "backend-access"
  }
}

# IAM policy for lambda (consumer) access
resource "aws_iam_policy" "lambda_sqs_access" {
  name        = "${var.project_tag}-${var.environment}-lambda-sqs-access"
  description = "IAM policy for Lambda to consume messages from SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-lambda-sqs-policy"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "lambda-access"
  }
}