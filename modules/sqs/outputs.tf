# modules/sqs/outputs.tf

output "queue_name" {
  description = "Name of the SQS queue"
  value       = aws_sqs_queue.main.name
}

output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.main.url
}

output "dlq_name" {
  description = "Name of the Dead Letter Queue (if enabled)"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].name : null
}

output "dlq_arn" {
  description = "ARN of the Dead Letter Queue (if enabled)"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue (if enabled)"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "backend_sqs_policy_arn" {
  description = "ARN of the IAM policy for backend SQS access"
  value       = aws_iam_policy.backend_sqs_access.arn
}

output "lambda_sqs_policy_arn" {
  description = "ARN of the IAM policy for Lambda SQS access"
  value       = aws_iam_policy.lambda_sqs_access.arn
}