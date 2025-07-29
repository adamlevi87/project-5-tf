# modules/argocd/main.tf

resource "helm_release" "argocd" {
    name       = var.helm_release_name
    namespace  = var.namespace
    repository = "https://argoproj.github.io/argo-helm"
    chart      = "argo-cd"
    version    = var.chart_version

    create_namespace = true

    values = [
        templatefile("${path.module}/values.yaml.tpl", {
            environment         = var.environment
            domain_name         = var.domain_name
            ingress_controller_class  = var.ingress_controller_class
            node_group_name           = var.node_group_name
            allowed_cidrs            = join(",", var.eks_allowed_cidr_blocks)
        })
    ]
}
