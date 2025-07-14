# main/providers.tf

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# provider "github" {
#   token = var.github_token
#   owner = var.github_org
# }

provider "aws" {
  region = var.aws_region
}