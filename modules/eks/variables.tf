# modules/eks/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

# Networking
variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster"
  type        = list(string)
}

variable "eks_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

# Node Group Configuration
variable "node_group_instance_types" {
  description = "EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_group_desired_capacity" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_group_max_capacity" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 3
}

variable "node_group_min_capacity" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

# Logging
variable "cluster_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cluster_log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "cluster_enabled_log_types" {
  description = "List of cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}