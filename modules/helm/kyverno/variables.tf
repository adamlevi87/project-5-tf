# modules/helm/kyverno/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "release_name" {
  description = "Helm release name for Kyverno"
  type        = string
}

variable "chart_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.3.10"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy Kyverno"
  type        = string
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "replicas" {
  description = "Number of Kyverno admission controller replicas"
  type        = number
  default     = 1
}

variable "cpu_requests" {
  description = "CPU requests for Kyverno admission controller"
  type        = string
  default     = "100m"
}

variable "memory_requests" {
  description = "Memory requests for Kyverno admission controller"
  type        = string
  default     = "256Mi"
}

variable "cpu_limits" {
  description = "CPU limits for Kyverno admission controller"
  type        = string
  default     = "1000m"
}

variable "memory_limits" {
  description = "Memory limits for Kyverno admission controller"
  type        = string
  default     = "512Mi"
}

variable "eks_dependency" {
  description = "Dependency on EKS cluster being ready"
  type        = any
  default     = null
}

variable "tolerations" {
  description = "Tolerations for Kyverno pods to run on tainted nodes"
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = string
  }))
  default = [
    {
      key      = "dedicated"
      operator = "Equal"
      value    = "critical"
      effect   = "NoSchedule"
    }
  ]
}

variable "node_selector" {
  description = "Node selector for Kyverno pods"
  type        = map(string)
  default = {
    "nodegroup-type" = "critical"
  }
}
