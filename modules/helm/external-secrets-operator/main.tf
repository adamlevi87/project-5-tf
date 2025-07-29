# modules/external-secrets-operator/main.tf

resource "kubernetes_namespace" "eso" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "eso" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace.eso.metadata[0].name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  dynamic "set" {
    for_each = var.set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  depends_on = [kubernetes_namespace.eso]
}
