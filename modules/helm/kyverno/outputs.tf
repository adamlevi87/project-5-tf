# modules/helm/kyverno/outputs.tf

output "release_name" {
  description = "Name of the Kyverno Helm release"
  value       = helm_release.kyverno.name
}

output "namespace" {
  description = "Namespace where Kyverno is deployed"
  value       = helm_release.kyverno.namespace
}

output "chart_version" {
  description = "Version of the Kyverno chart deployed"
  value       = helm_release.kyverno.chart
}

output "kyverno_ready" {
  description = "Indicates that Kyverno is deployed and ready"
  value       = helm_release.kyverno.status == "deployed"
}
