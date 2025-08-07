# modules/backend/variables.tf

# variable "cluster_name" {
#   description = "Name of the EKS cluster"
#   type        = string
# }

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from the EKS module"
  type        = string
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL (e.g. https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDOCID)"
}

variable "namespace" {
  description = "namespace used"
  type        = string
}

variable "service_account_name" {
  description = "service_account_name name"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  type        = string
}

variable "node_group_security_group" {
  type        = string
  description = "Security group ID attached to the node group"
}

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret used by the application"
  type        = string
}
