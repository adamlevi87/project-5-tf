# modules/external-dns/outputs.tf

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}
