variable "services" {
  type        = list(string)
  description = "Lista dei microservizi ECR"
  default     = [
    "beacon-api",
    "command-api",
    "ops-dashboard",
    "triage-worker"
  ]
}

variable "common_tags" {
  type        = map(string)
  description = "Tag generati dal modulo tags"
}