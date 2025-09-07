# modules/waf/outputs.tf

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "ip_set_arn" {
  description = "WAF IP Set ARN"
  value       = aws_wafv2_ip_set.allowed_ips.arn
}
