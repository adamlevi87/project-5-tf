# modules/iam-github-oidc/variables.tf

variable "github_org" {
  type        = string
  description = "GitHub organization or user"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string
}

# Move creation to the .requirements folder
# variable "oidc_provider_url" {
#   type        = string
#   description = "OIDC provider URL (e.g., token.actions.githubusercontent.com)"
# }

variable "aws_iam_openid_connect_provider_github_arn" {
  type        = string
  description = "github provider arn [created beforhand, using .requirements folder]"
  sensitive   = true
}