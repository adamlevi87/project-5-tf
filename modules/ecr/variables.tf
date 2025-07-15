# modules/ecr/variables.tf

variable "ecr_repository_name" {
  description = "Base name prefix for all ECR repositories"
  type        = string
}

variable "project_tag" {
  type        = string
  description = "Tag to identify the project"
}

variable "environment" {
  description = "environment name for tagging resources"
  type        = string
}

variable "ecr_repositories_applications" {
  description = "List of application names to create ECR repositories for"
  type        = list(string)
}