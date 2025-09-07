# modules/lambda/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function (will be prefixed with project-environment)"
  type        = string
  default     = "message-processor"
}

variable "lambda_source_dir" {
  description = "Path to the directory containing Lambda source code"
  type        = string
  default     = "lambda-code"
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "environment_variables" {
  description = "Additional environment variables for Lambda"
  type        = map(string)
  default     = {}
}

# SQS Integration
variable "sqs_queue_arn" {
  description = "ARN of the SQS queue to connect to Lambda"
  type        = string
}

variable "sqs_lambda_policy_arn" {
  description = "ARN of the IAM policy for Lambda SQS access"
  type        = string
}

variable "batch_size" {
  description = "Maximum number of messages to process in a single Lambda invocation"
  type        = number
  default     = 1
  validation {
    condition     = var.batch_size >= 1 && var.batch_size <= 10000
    error_message = "Batch size must be between 1 and 10000."
  }
}

variable "maximum_batching_window_in_seconds" {
  description = "Maximum time to wait before invoking Lambda (even if batch size not reached)"
  type        = number
  default     = 5
  validation {
    condition     = var.maximum_batching_window_in_seconds >= 0 && var.maximum_batching_window_in_seconds <= 300
    error_message = "Maximum batching window must be between 0 and 300 seconds."
  }
}

variable "maximum_concurrency" {
  description = "Maximum number of concurrent Lambda invocations"
  type        = number
  default     = 10
  validation {
    condition     = var.maximum_concurrency >= 2 && var.maximum_concurrency <= 1000
    error_message = "Maximum concurrency must be between 2 and 1000."
  }
}

# S3 Integration
variable "s3_bucket_name" {
  description = "Name of the S3 bucket for Lambda to write to"
  type        = string
}

# variable "s3_lambda_policy_arn" {
#   description = "ARN of the IAM policy for Lambda S3 access"
#   type        = string
# }

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# KMS Integration
variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 bucket encryption"
  type        = string
}