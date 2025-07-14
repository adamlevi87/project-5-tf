# modules/alb/main.tf

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_tag}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP access from internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTP access from internet"
  }

  # HTTPS access from internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTPS access from internet"
  }

  # Outbound to EKS nodes (will be refined with target groups)
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Outbound to EKS nodes"
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-alb-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "alb-security"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_tag}-${var.environment}-${var.alb_name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout              = var.idle_timeout
  enable_http2              = var.enable_http2

  # Access logs configuration (optional)
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${var.alb_name}"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "application-load-balancer"
  }
}

# Target Groups
resource "aws_lb_target_group" "app_target_groups" {
  for_each = var.target_groups

  name        = "${var.project_tag}-${var.environment}-${each.value.name}"
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = each.value.target_type

  health_check {
    enabled             = each.value.health_check.enabled
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    timeout             = each.value.health_check.timeout
    interval            = each.value.health_check.interval
    path                = each.value.health_check.path
    matcher             = each.value.health_check.matcher
    protocol            = each.value.health_check.protocol
    port                = each.value.health_check.port
  }

  # Preserve client IP for applications
  preserve_client_ip = each.value.target_type == "ip" ? "true" : "false"

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${each.value.name}-tg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "target-group"
    Application = each.value.name
  }
}

# HTTPS Listener (Primary)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Default action - return 404 for unmatched requests
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-https-listener"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# HTTP Listener (Redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-http-listener"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Listener Rules
resource "aws_lb_listener_rule" "app_rules" {
  for_each = var.listener_rules

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_groups[each.value.target_group_key].arn
  }

  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "host_header" {
        for_each = condition.value.type == "host-header" ? [1] : []
        content {
          values = condition.value.values
        }
      }

      dynamic "path_pattern" {
        for_each = condition.value.type == "path-pattern" ? [1] : []
        content {
          values = condition.value.values
        }
      }
    }
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-rule-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}