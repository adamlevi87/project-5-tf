# modules/aws_auth_config/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

# Read existing aws-auth configmap to preserve node group roles
data "kubernetes_config_map_v1" "existing_aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  depends_on = [var.eks_dependency]
}

locals {
  # Parse existing mapRoles
  existing_map_roles = try(yamldecode(data.kubernetes_config_map_v1.existing_aws_auth.data["mapRoles"]), [])
  existing_map_users = try(yamldecode(data.kubernetes_config_map_v1.existing_aws_auth.data["mapUsers"]), [])
  
  # Merge existing roles with new roles (new roles take precedence)
  merged_map_roles = concat(local.existing_map_roles, var.map_roles)
  merged_map_users = concat(local.existing_map_users, [
    for user_key, user in var.eks_user_access_map : {
      userarn  = user.userarn
      username = user.username
      groups   = user.groups
    }
  ])
}

resource "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    name      = "aws-auth" 
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.merged_map_roles)
    mapUsers = yamlencode(local.merged_map_users)
  }
  
  lifecycle {
    replace_triggered_by = [data.kubernetes_config_map_v1.existing_aws_auth]
  }
}
