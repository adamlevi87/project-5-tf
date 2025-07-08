# modules/sqs/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "queue_name" {
  description = "Name of the SQS queue (will be prefixed with project-environment)"
  type        = string
  default     = "app-queue"
}

variable "message_retention_seconds" {
  description = "Number of seconds SQS retains a message"
  type        = number
  default     = 1209600  # 14 days (default SQS maximum)
  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "Message retention must be between 60 seconds and 1209600 seconds (14 days)."
  }
}

variable "visibility_timeout_seconds" {
  description = "Number of seconds a message is invisible after being received"
  type        = number
  default     = 30
  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "Visibility timeout must be between 0 and 43200 seconds (12 hours)."
  }
}

variable "receive_wait_time_seconds" {
  description = "Number of seconds to wait for messages (long polling)"
  type        = number
  default     = 20
  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "Receive wait time must be between 0 and 20 seconds."
  }
}

variable "enable_dlq" {
  description = "Enable Dead Letter Queue for failed messages"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Maximum number of times a message can be received before moving to DLQ"
  type        = number
  default     = 3
  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "Max receive count must be between 1 and 1000."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Number of seconds DLQ retains a message"
  type        = number
  default     = 1209600  # 14 days
  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "DLQ message retention must be between 60 seconds and 1209600 seconds (14 days)."
  }
}