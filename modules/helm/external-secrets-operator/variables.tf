# modules/external-secrets-operator/variables.tf

variable "namespace" {
  type        = string
  default     = "external-secrets"
  description = "Namespace to install ESO into"
}

variable "chart_version" {
  type        = string
  default     = "0.9.17" # or latest stable
  description = "Version of the ESO Helm chart"
}

variable "set_values" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
  description = "Extra Helm values to set"
}
