variable "repository_name" {
  description = "Name of the target GitHub repository"
  type        = string
}

variable "github_secrets" {
  description = "Map of secrets to set in the GitHub repo"
  type        = map(string)
}

variable "github_variables" {
  description = "Map of plain variables to set in the GitHub repo"
  type        = map(string)
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"
}