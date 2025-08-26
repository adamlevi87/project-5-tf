# modules/helm/metrics-server/main.tf

resource "helm_release" "this" {
  name       = var.release_name
  
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_version
  
  namespace        = var.namespace
  create_namespace = false

  # Configuration for metrics-server
  set = [
    # EKS-specific args
    {
      name  = "args"
      value = "{--cert-dir=/tmp,--secure-port=4443,--kubelet-preferred-address-types=InternalIP\\,ExternalIP\\,Hostname,--kubelet-use-node-status-port,--metric-resolution=15s,--kubelet-insecure-tls}"
    },
    # Disable Prometheus integration (not needed for HPA)
    {
      name  = "metrics.enabled"
      value = "false"
    },
    {
      name  = "serviceMonitor.enabled"
      value = "false"
    },
    # Resource configuration
    {
      name  = "resources.requests.cpu"
      value = var.cpu_requests
    },
    {
      name  = "resources.requests.memory"
      value = var.memory_requests
    },
    {
      name  = "resources.limits.cpu"
      value = var.cpu_limits
    },
    {
      name  = "resources.limits.memory"
      value = var.memory_limits
    },
    # Node affinity for system workloads (Linux nodes only)
    {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
      value = "kubernetes.io/os"
    },
    {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
      value = "In"
    },
    {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
      value = "linux"
    }
  ]

  depends_on = [var.eks_dependency, var.lbc_webhook_ready]
}