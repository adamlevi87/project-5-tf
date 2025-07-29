# modules/backend_irsa/main.tf

locals {
  # arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABCDEF1234567890
  # ["arn:aws:iam::123456789012:", "oidc.eks.us-east-1.amazonaws.com/id/ABCDEF1234567890"]
  # element[1] means the 2nd part of the variable
  oidc_provider_host = element(
    split("oidc-provider/", var.oidc_provider_arn),
    1
  )

  sa_subject = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

resource "aws_iam_role" "this" {
  name = "${var.service_account_name}-irsa-role"

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
            "${local.oidc_provider_host}:sub" = local.sa_subject
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
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}
