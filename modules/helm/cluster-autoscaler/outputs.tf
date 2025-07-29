output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by the cluster-autoscaler"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "cluster_autoscaler_service_account_name" {
  description = "Name of the Kubernetes service account for cluster-autoscaler"
  value       = kubernetes_service_account.cluster_autoscaler.metadata[0].name
}

output "cluster_autoscaler_helm_release_name" {
  description = "Helm release name of the cluster-autoscaler"
  value       = helm_release.cluster_autoscaler.name
}
