# modules/helm/metrics-server/main.tf

resource "helm_release" "this" {
  name       = var.release_name
  
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_version
  
  namespace        = var.namespace
  create_namespace = false

  # EKS-specific configuration
  set {
    name  = "args"
    value = "{--cert-dir=/tmp,--secure-port=4443,--kubelet-preferred-address-types=InternalIP\\,ExternalIP\\,Hostname,--kubelet-use-node-status-port,--metric-resolution=15s,--kubelet-insecure-tls}"
  }

  set {
    name  = "metrics.enabled"
    value = "false"
  }

  set {
    name  = "serviceMonitor.enabled"
    value = "false"
  }

  # Resource configuration
  set {
    name  = "resources.requests.cpu"
    value = var.cpu_requests
  }

  set {
    name  = "resources.requests.memory"
    value = var.memory_requests
  }

  set {
    name  = "resources.limits.cpu"
    value = var.cpu_limits
  }

  set {
    name  = "resources.limits.memory"
    value = var.memory_limits
  }

  # Node affinity for system workloads
  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
    value = "kubernetes.io/os"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
    value = "In"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
    value = "linux"
  }

  depends_on = [var.eks_dependency]

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "metrics-server"
  }
}
