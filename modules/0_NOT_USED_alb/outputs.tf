# modules/alb/outputs.tf

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "target_group_arns" {
  description = "ARNs of the target groups"
  value       = { for k, v in aws_lb_target_group.app_target_groups : k => v.arn }
}

output "target_group_arn_suffixes" {
  description = "ARN suffixes of the target groups for CloudWatch metrics"
  value       = { for k, v in aws_lb_target_group.app_target_groups : k => v.arn_suffix }
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "listener_rule_arns" {
  description = "ARNs of the listener rules"
  value       = { for k, v in aws_lb_listener_rule.app_rules : k => v.arn }
}