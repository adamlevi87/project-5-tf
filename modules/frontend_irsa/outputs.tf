# modules/frontend_irsa/outputs.tf

output "service_account_name" {
  value = kubernetes_service_account.this.metadata[0].name
}

output "iam_role_arn" {
  value = aws_iam_role.this.arn
}
