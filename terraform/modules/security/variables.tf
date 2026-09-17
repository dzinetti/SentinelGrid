variable "vpc_id" {
  type        = string
  description = "ID della VPC"
}

variable "environment" {
  type        = string
  description = "Ambiente di deploy (prod, dev)"
}

variable "common_tags" {
  type        = map(string)
  description = "Tag generati dal modulo tags"
}

# NUOVE VARIABILI PER IRSA EBS CSI
variable "oidc_provider_arn" {
  type        = string
  description = "ARN dell'OIDC Provider generato dal modulo EKS"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL dell'OIDC Provider (senza https://) generato dal modulo EKS"
}