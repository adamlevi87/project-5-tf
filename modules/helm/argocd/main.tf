# modules/argocd/main.tf

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

    set {
        name  = "serviceAccount.create"
        value = "false"  # We create it manually above
    }

    set {
        name  = "serviceAccount.name"
        value = "${var.service_account_name}"
    }

    values = [
        templatefile("${path.module}/values.yaml.tpl", {
            environment         = var.environment
            domain_name         = var.domain_name
            ingress_controller_class  = var.ingress_controller_class
            node_group_name           = var.node_group_name
            allowed_cidrs            = join(",", var.eks_allowed_cidr_blocks)
        })
    ]

    depends_on = [
        kubernetes_service_account.this
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

