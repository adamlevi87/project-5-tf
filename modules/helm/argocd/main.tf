# modules/argocd/main.tf

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
  name       = var.release_name
  
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  
  namespace  = var.namespace
  create_namespace = false

  # set = [
  #   {
  #     name  = "serviceAccount.create"
  #     value = "false"  # We create it manually above
  #   },
  #   {
  #     name  = "serviceAccount.name"
  #     value = "${var.service_account_name}"
  #   }
  # ]

  values = [
      templatefile("${path.module}/values.yaml.tpl", {
          service_account_name = var.service_account_name
          #environment         = var.environment
          domain_name         = var.domain_name
          ingress_controller_class  = var.ingress_controller_class
          alb_group_name           = var.alb_group_name
          #allowed_cidrs            = join(",", var.argocd_allowed_cidr_blocks)
          security_group_id         = aws_security_group.argocd.id
          acm_cert_arn             = var.acm_cert_arn
      })
  ]

  depends_on = [
      kubernetes_namespace.this,
      kubernetes_service_account.this,
      aws_security_group.argocd,
      var.lbc_webhook_ready
  ]
}

resource "local_file" "rendered_argo_values" {
  content  = templatefile("${path.module}/values.yaml", {
    service_account_name = var.service_account_name
    #environment         = var.environment
    domain_name         = var.domain_name
    ingress_controller_class  = var.ingress_controller_class
    alb_group_name           = var.alb_group_name
    #allowed_cidrs            = join(",", var.argocd_allowed_cidr_blocks)
    security_group_id         = aws_security_group.argocd.id
    acm_cert_arn              = var.acm_cert_arn
  })

  filename = "${path.module}/rendered-values-debug.yaml"

  depends_on = [
      kubernetes_service_account.this,
      aws_security_group.argocd
  ]
}


# Kubernetes service account
resource "kubernetes_service_account" "this" {
  metadata {
    name      = "${var.service_account_name}"
    namespace = "${var.namespace}"
    # annotations = {
    #   "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    # }
  }
}

# Security Group for ArgoCD
resource "aws_security_group" "argocd" {
  name        = "${var.project_tag}-${var.environment}-argocd-sg"
  description = "Security group for argocd"
  vpc_id      = var.vpc_id

  # Allow ArgoCD access from the outside
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.argocd_allowed_cidr_blocks
      description = "ArgoCD access on port ${ingress.value}"
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
    Name        = "${var.project_tag}-${var.environment}-argocd-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security"
  }
}

resource "aws_security_group_rule" "allow_alb_to_argocd_pods" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  #security_group_id        = tolist(data.aws_instance.first_node.security_groups)[0]  # or manually "sg-0a9d986ac63a06d9f"
  security_group_id        = var.node_group_security_group
  source_security_group_id = aws_security_group.argocd.id
  description              = "Allow ALB to access ArgoCD pods on port 8080"
}
