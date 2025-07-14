# modules/secrets-manager/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
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