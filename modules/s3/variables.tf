# modules/s3/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "enable_lifecycle_policy" {
  description = "Enable S3 lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "data_retention_days" {
  description = "Number of days to retain data before deletion (0 = never delete)"
  type        = number
  default     = 0
  validation {
    condition     = var.data_retention_days >= 0
    error_message = "Data retention days must be 0 or greater (0 means never delete)."
  }
}