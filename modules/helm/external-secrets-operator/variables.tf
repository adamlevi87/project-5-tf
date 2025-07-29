# modules/external-secrets-operator/variables.tf

variable "project_tag" {
  description = "Project tag used for naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string
}

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

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN from the EKS cluster"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL (e.g. https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDOCID)"
}