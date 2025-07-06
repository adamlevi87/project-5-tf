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
