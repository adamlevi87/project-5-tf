# modules/waf/main.tf

# IP Set for allowed IPs
resource "aws_wafv2_ip_set" "allowed_ips" {
  name               = "${var.project_tag}-${var.environment}-allowed-ips"
  description        = "IP addresses allowed to access ${var.project_tag}"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"

  addresses = var.allowed_ip_addresses

  tags = {
    Name        = "${var.project_tag}-${var.environment}-allowed-ips"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_tag}-${var.environment}-waf-acl"
  description = "WAF ACL for ${var.project_tag} CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    block {}
  }

  # Rule 1: Allow specific IP addresses
  rule {
    name     = "AllowSpecificIPs"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allowed_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowSpecificIPs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Block common attacks  
  rule {
    name     = "BlockCommonAttacks"
    priority = 2

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockCommonAttacks"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_tag}-${var.environment}-waf-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-waf-acl"
    Project     = var.project_tag
    Environment = var.environment
  }
}
