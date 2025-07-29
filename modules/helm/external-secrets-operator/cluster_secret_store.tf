# # modules/external-secrets-operator/cluster_secret_store.tf

# data "kubernetes_namespace" "kube_system" {
#   metadata {
#     name = "kube-system"
#   }
# }

# resource "kubernetes_manifest" "eso_cluster_secret_store" {
#   manifest = {
#     apiVersion = "external-secrets.io/v1beta1"
#     kind       = "ClusterSecretStore"
#     metadata = {
#       name = "aws-secretsmanager"
#     }
#     spec = {
#       provider = {
#         aws = {
#           service = "SecretsManager"
#           region  = var.aws_region

#           auth = {
#             jwt = {
#               serviceAccountRef = {
#                 name      = var.service_account_name
#                 namespace = var.namespace
#               }
#             }
#           }
#         }
#       }
#     }
#   }

#   depends_on = [
#     helm_release.this,
#     data.kubernetes_namespace.kube_system  # This ensures K8s connectivity
#   ]
# }
