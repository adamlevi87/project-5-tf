# modules/ecr/variables.tf

variable "name" {
  type        = string
  description = "Name of the ECR repository"
}

variable "project_tag" {
  type        = string
  description = "Tag to identify the project"
}

variable "environment" {
  description = "environment name for tagging resources"
  type        = string
}