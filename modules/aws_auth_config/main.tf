# modules/aws_auth_config/main.tf

locals {
  github_actions_role_arn = [
    for role in var.map_roles : role.rolearn
    if role.username == "github"
  ][0]
}

# the delete will only run if the config map that exists does not have the github actions arn
resource "null_resource" "delete_default_aws_auth" {
  provisioner "local-exec" {
    command = <<EOT
if ! kubectl get configmap aws-auth -n kube-system -o yaml | grep -q '${local.github_actions_role_arn}'; then
  echo "Default aws-auth configmap detected. Deleting..."
  kubectl delete configmap aws-auth -n kube-system
else
  echo "aws-auth already contains GitHub Actions role. Skipping deletion."
fi
EOT
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [var.eks_dependency]
}




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
  
  depends_on = [null_resource.delete_default_aws_auth]
}
