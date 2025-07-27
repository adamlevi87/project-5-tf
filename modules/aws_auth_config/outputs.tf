# modules/aws_auth_config/outputs.tf

output "aws_auth_config_map_name" {
  value = kubernetes_config_map.aws_auth.metadata[0].name
}
