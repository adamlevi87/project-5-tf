# modules/argocd/variables.tf

variable "helm_release_name" {
  type        = string
  description = "Name of the Helm release for ArgoCD"
  default     = "argocd"
}

variable "namespace" {
  type        = string
  default     = "argocd"
  description = "Namespace to install ArgoCD"
}

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

