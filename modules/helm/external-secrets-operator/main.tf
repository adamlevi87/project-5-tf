# modules/external-secrets-operator/main.tf

# terraform {
#   required_providers {
#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#       version = "~> 2.38"
#     }
#     helm = {
#       source  = "hashicorp/helm"
#       version = "~> 3.0.2"
#     }
#   }
# }


resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "this" {
  name       = "${var.release_name}"
  
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  namespace  = "${var.namespace}"
  create_namespace = false

  # Wait for all resources to be ready
  wait                = true
  wait_for_jobs      = true
  timeout            = 300  # 5 minutes
  set = concat([
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = var.service_account_name
    }
  ], var.set_values)

  # dynamic "set" {
  #   for_each = var.set_values
  #   content {
  #     name  = set.value.name
  #     value = set.value.value
  #   }
  # }

  depends_on = [
    aws_iam_role_policy_attachment.this,
    kubernetes_service_account.this,
    kubernetes_namespace.this,
    var.lbc_webhook_ready
  ]
}

resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-eso"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity",
      Effect = "Allow",
      Principal = {
        Federated = var.oidc_provider_arn
      },
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eso-role"
    Environment = var.environment
    Project     = var.project_tag
    Purpose     = "eso-irsa"
  }
}

resource "aws_iam_policy" "this" {
  name        = "${var.project_tag}-${var.environment}-eso-policy"
  description = "Allow ESO to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
      "meta.helm.sh/release-name"  = var.release_name                # e.g. "external-secrets-dev"
      "meta.helm.sh/release-namespace" = var.namespace
    }
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }
}
