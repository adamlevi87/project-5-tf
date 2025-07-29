# modules/argocd/variables.tf

variable "chart_version" {
  type        = string
  default     = "8.2.3" # Latest stable as of July 2025
}

variable "domain_name" {
  type        = string
  description = "Domain name (e.g., dev.example.com)"
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "eks_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the ALB"
}

variable "ingress_controller_class" {
  type        = string
  description = "Ingress Controller Class Resource Name"
  default     = "alb"
}

variable "node_group_name" {
  type        = string
  description = "Node Group Name"
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

