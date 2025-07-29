# modules/external-secrets-operator/outputs.tf

output "namespace" {
  value = kubernetes_namespace.eso.metadata[0].name
}
