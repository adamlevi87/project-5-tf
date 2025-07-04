variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
}

variable "project_tag" {
  type        = string
  description = "Tag used for project identification"
}

variable "environment" {
  description = "environment name for tagging resources"
  type        = string
}

variable "nat_mode" {
  description = "Controls the NAT gateway setup. Options: single (1 NAT), real (3 NATs), endpoints (use VPC endpoints instead)"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["real", "single", "endpoints"], var.nat_mode)
    error_message = "nat_mode must be one of: single, real, endpoints"
  }
}
