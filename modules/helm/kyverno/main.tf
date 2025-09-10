# modules/helm/kyverno/main.tf

resource "helm_release" "kyverno" {
  name       = var.release_name
  
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = var.chart_version
  
  namespace        = var.namespace
  create_namespace = var.create_namespace

  # Use global tolerations so Kyverno can start on critical nodes
  values = [yamlencode({
    global = {
      tolerations = [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "critical"
          effect   = "NoSchedule"
        }
      ]
      nodeSelector = {
        "nodegroup-type" = "critical"
      }
    }
    admissionController = {
      replicas = var.replicas
      resources = {
        limits = {
          memory = var.memory_limits
        }
        requests = {
          cpu    = var.cpu_requests
          memory = var.memory_requests
        }
      }
    }
    
    backgroundController = {
      resources = {
        limits = {
          cpu    = "200m"  # Kyverno default
          memory = "128Mi" # Kyverno default  
        }
        requests = {
          cpu    = "100m"  # Kyverno default
          memory = "64Mi"  # Kyverno default
        }
      }
    }
    
    cleanupController = {
      resources = {
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "64Mi"
        }
      }
    }
    
    reportsController = {
      resources = {
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "64Mi"
        }
      }
    }
  })]
}

# Apply the toleration injection policy
resource "kubernetes_manifest" "toleration_injection_policy" {
  manifest = yamldecode(file("${path.module}/toleration-injection-policy.yaml"))
  
  depends_on = [helm_release.kyverno]
}
