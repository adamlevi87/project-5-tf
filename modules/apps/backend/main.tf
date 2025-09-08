# modules/backend/main.tf

# terraform {
#   required_providers {
#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#       version = "~> 2.38"
#     }
#   }
# }

# locals {
#   # arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABCDEF1234567890
#   # ["arn:aws:iam::123456789012:", "oidc.eks.us-east-1.amazonaws.com/id/ABCDEF1234567890"]
#   # element[1] means the 2nd part of the variable
#   oidc_provider_host = element(
#     split("oidc-provider/", var.oidc_provider_arn),
#     1
#   )

#   sa_subject = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
# }

resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-${var.service_account_name}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}",
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "${var.service_account_name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "s3:PutObject",
      #     "s3:GetObject"
      #   ]
      #   Resource = "${var.s3_bucket_arn}/*"
      # },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.sqs_queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "${var.secret_arn}"
      }
    ]
  })
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace

    labels = {
      name = var.namespace
    }
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.this.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

# Security Group for Backend
resource "aws_security_group" "backend" {
  name        = "${var.project_tag}-${var.environment}-backend-sg"
  description = "Security group for backend"
  vpc_id      = var.vpc_id

  # Allow Backend access from the outside
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Backend access on port ${ingress.value}"
    }
  }

  # Outbound rules (usually not needed but good practice)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-backend-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "backend-security"
  }
}

resource "aws_security_group_rule" "allow_alb_to_backend_pods" {
  for_each = var.node_group_security_groups

  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = each.value
  source_security_group_id = aws_security_group.backend.id
  description              = "Allow ALB to access Backend pods on port 3000 (${each.key} nodes)"
}
