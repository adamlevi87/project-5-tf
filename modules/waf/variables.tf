# modules/waf/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses (CIDR notation) allowed to access the CloudFront distribution"
  type        = list(string)
  default     = []
  
  validation {
    condition = length(var.allowed_ip_addresses) > 0
    error_message = "At least one IP address must be specified."
  }
}
