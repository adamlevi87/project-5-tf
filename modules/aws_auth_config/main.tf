# modules/aws_auth_config/main.tf

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(var.map_roles)
    mapUsers = yamlencode([
      for user_key, user in var.eks_user_access_map : {
        userarn  = user.userarn
        username = user.username
        groups   = user.groups
      }
    ])
  }

  depends_on = [var.eks_dependency]
}
