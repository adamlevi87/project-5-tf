# modules/aws_load_balancer_controller/outputs.tf

output "webhook_ready" {
  description = "Indicates AWS LBC webhook is deployed"
  value       = helm_release.this.status
  depends_on  = [helm_release.this]
}
