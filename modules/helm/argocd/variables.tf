# modules/argocd/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "chart_version" {
  type        = string
  default     = "8.2.3" # Latest stable as of July 2025
}

variable "domain_name" {
  type        = string
  description = "Domain name (e.g., dev.example.com)"
}

variable "argocd_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the ALB-argoCD"
}

variable "ingress_controller_class" {
  type        = string
  description = "Ingress Controller Class Resource Name"
  default     = "alb"
}

variable "node_group_security_group" {
  type        = string
  description = "Security group ID attached to the node group"
}

variable "service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account to use for the Helm chart"
}

variable "release_name" {
  type        = string
  description = "The Helm release name"
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to install the Helm release into"
}

variable "acm_cert_arn" {
  description = "ARN of the ACM certificate to use for ALB HTTPS listener"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "lbc_webhook_ready" {
  description = "AWS LBC webhook readiness signal"
  type        = string
}

variable "alb_group_name" {
  description = "Group name for ALB to allow sharing across multiple Ingress resources"
  type        = string
  default     = "alb_shared_group"  # Optional: override in dev/main.tf if needed
}

variable "backend_security_group_id" {
  description = "ID of the security group for the backend"
  type        = string
}

variable "frontend_security_group_id" {
  description = "ID of the security group for the frontend"
  type        = string
}
