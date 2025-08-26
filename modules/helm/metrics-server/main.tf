# modules/helm/metrics-server/main.tf

resource "helm_release" "this" {
  name       = var.release_name
  
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_version
  
  namespace        = var.namespace
  create_namespace = false

  # Configuration for metrics-server
  values = [yamlencode({
    args = [
      "--cert-dir=/tmp",
      "--secure-port=4443",
      "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
      "--kubelet-use-node-status-port",
      "--kubelet-insecure-tls"
    ]
    livenessProbe = {
      httpGet = { port = 4443 }
    }
    readinessProbe = {
      httpGet = { port = 4443 }
    }
    metrics = {
      enabled = false
    }
    serviceMonitor = {
      enabled = false
    }
    resources = {
      requests = {
        cpu    = var.cpu_requests
        memory = var.memory_requests
      }
      limits = {
        cpu    = var.cpu_limits
        memory = var.memory_limits
      }
    }
    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [{
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            }]
          }]
        }
      }
    }
  })]

  depends_on = [var.eks_dependency, var.lbc_webhook_ready]
}