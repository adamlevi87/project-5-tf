# modules/external-secrets-operator/outputs.tf

output "namespace" {
  value = kubernetes_namespace.this.metadata[0].name
}
output "argocd_github_sso_secret_name" {
  value = local.argocd_github_sso_secret_name
}
