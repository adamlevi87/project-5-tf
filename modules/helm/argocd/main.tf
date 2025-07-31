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
            node_group_name           = var.node_group_name
            allowed_cidrs            = join(",", var.eks_allowed_cidr_blocks)
            acm_cert_arn             = var.acm_cert_arn
        })
    ]

    depends_on = [
        kubernetes_service_account.this
  ]
}

resource "local_file" "rendered_argo_values" {
  content  = templatefile("${path.module}/values.yaml.tpl", {
    service_account_name = var.service_account_name
    #environment         = var.environment
    domain_name         = var.domain_name
    ingress_controller_class  = var.ingress_controller_class
    node_group_name           = var.node_group_name
    allowed_cidrs            = join(",", var.eks_allowed_cidr_blocks)
    acm_cert_arn              = module.acm.aws_acm_certificate.this.arn
  })

  filename = "${path.module}/rendered-values-debug.yaml"
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

