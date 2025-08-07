# main/variables.tf

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "primary_availability_zones" {
  description = "Number of primary AZs that should always exist (houses primary NAT gateway)"
  type        = number
  default     = 1
  validation {
    condition     = var.primary_availability_zones >= 1 && var.primary_availability_zones <= 3
    error_message = "Primary availability zones must be between 1 and 3"
  }
}

variable "additional_availability_zones" {
  description = "Number of additional AZs (optional in single mode, required in real mode)"
  type        = number
  default     = 0
  validation {
    condition     = var.additional_availability_zones >= 0
    error_message = "Additional availability zones must be 0 or greater"
  }
}

variable "nat_mode" {
  description = "NAT gateway mode: 'single' (primary NAT only), 'real' (NAT per AZ), or 'endpoints' (no NATs)"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["single", "real", "endpoints"], var.nat_mode)
    error_message = "NAT mode must be one of: single, real, endpoints"
  }
}

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# RDS Database Configuration
variable "rds_postgres_version" {
  description = "PostgreSQL version for RDS"
  type        = string
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "rds_database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "rds_database_username" {
  description = "Username for the database"
  type        = string
}

variable "rds_database_port" {
  description = "Port number for the RDS PostgreSQL instance"
  type        = number
  default     = 5432
}

# RDS Storage Configuration
variable "rds_allocated_storage" {
  description = "Initial storage allocation in GB"
  type        = number
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage allocation in GB (for autoscaling)"
  type        = number
}

variable "rds_storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
}

# RDS Backup and Maintenance
variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
}

variable "rds_backup_window" {
  description = "Backup window in UTC (format: hh24:mi-hh24:mi)"
  type        = string
}

variable "rds_maintenance_window" {
  description = "Maintenance window in UTC (format: ddd:hh24:mi-ddd:hh24:mi)"
  type        = string
}

# RDS Protection and Snapshots
variable "rds_deletion_protection" {
  description = "Enable deletion protection for RDS instance"
  type        = bool
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot when destroying RDS instance"
  type        = bool
}

# RDS Monitoring
variable "rds_enable_performance_insights" {
  description = "Enable Performance Insights for RDS"
  type        = bool
}

variable "rds_monitoring_interval" {
  description = "Monitoring interval in seconds (0 to disable)"
  type        = number
}

variable "secrets_config" {
  description = "Map of Configurations of secrets to create"
  type = map(object({
    description        = string
    generate_password  = bool
    password_length    = optional(number, 16)
    password_special   = optional(bool, true)
    secret_value       = optional(string, "")
    password_override_special = optional(string, "")
  }))
  
  validation {
    condition = alltrue([
      for name, config in var.secrets_config : 
      config.generate_password == true || config.secret_value != ""
    ])
    error_message = "Each secret must either have generate_password=true or provide a secret_value."
  }
}

variable "ecr_repository_name" {
  description = "Base name prefix for all ECR repositories"
  type        = string
}

variable "ecr_repositories_applications" {
  description = "List of application names to create ECR repositories for"
  type        = list(string)
}

variable "domain_name" {
  type        = string
  description = "The root domain to configure (e.g., yourdomain.com)"
}

variable "subdomain_name" {
  type        = string
  description = "The subdomain for the app (e.g., chatbot)"
}

# EKS Cluster Configuration
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_api_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

variable "argocd_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

# EKS Node Group Configuration
variable "eks_node_instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
}

variable "eks_node_desired_capacity" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
}

variable "eks_node_max_capacity" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
}

variable "eks_node_min_capacity" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
}

# EKS Logging Configuration
variable "eks_log_retention_days" {
  description = "CloudWatch log retention period in days for EKS cluster"
  type        = number
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection for the Application Load Balancer"
  type        = bool
  default     = false
  validation {
    condition     = can(var.alb_deletion_protection)
    error_message = "ALB deletion protection must be a boolean value (true or false)."
  }
}

variable "backend_service_namespace" {
  description = "Namespace where the backend service account is deployed"
  type        = string
  default     = "default"
}

variable "backend_service_account_name" {
  description = "Name of the backend service account"
  type        = string
  default     = "backend-sa"
}

variable "frontend_service_namespace" {
  description = "Namespace where the frontend service account is deployed"
  type        = string
  default     = "default"
}

variable "frontend_service_account_name" {
  description = "Name of the frontend service account"
  type        = string
  default     = "frontend-sa"
}

variable "github_application_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

# Application's repo PAT github token to allow TF repo to write into the application repo
# When run from the workflow: will be pulled from the TF's application repo secrets so it must exists beforehand
# example for the cli command usage: terraform plan -var="github_token=YOURKEY" ..."
variable "github_token" {
description = "GitHub PAT with access to manage secrets"
type        = string
sensitive   = true
}

# github provider ARN, created using the requirements folder
# When run from the workflow: will be pulled from the TF's application repo secrets
# example: terraform plan -var="aws_iam_openid_connect_provider_github_arn=ARN"
variable "aws_iam_openid_connect_provider_github_arn" {
  type        = string
  description = "github provider arn [created beforhand, using .requirements folder]"
  sensitive   = true
}

# this is the arn that was created using the requirements folder
# which we then set as the secret: AWS_ROLE_TO_ASSUME for the TF repo
variable "github_oidc_role_arn" {
  description = "ARN of the GitHub OIDC role used to deploy from GitHub Actions"
  type        = string
}

variable "eks_user_access_map" {
  description = "Map of IAM users to be added to aws-auth with their usernames and groups"
  type = map(object({
    username = string
    groups   = list(string)
  }))
  default = {}
}

variable "argocd_namespace" {
  type        = string
  description = "Kubernetes namespace for ArgoCD"
  default     = "argocd"
}

variable "argocd_helm_release_base_name" {
  type        = string
  description = "Helm release base name for ArgoCD"
  default     = "argocd"
}

variable "argocd_chart_version" {
  type        = string
  description = "ArgoCD Helm chart version"
  default     = "8.2.3"
}

variable "argocd_base_domain_name" {
  type        = string
  description = "Base domain name for ArgoCD"
  default     = "argocd"
}

variable "frontend_base_domain_name" {
  type        = string
  description = "Base domain name for the frontend"
}

variable "backend_base_domain_name" {
  type        = string
  description = "Base domain name for the backend"
}
