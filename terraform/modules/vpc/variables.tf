variable "environment" {
  type        = string
  description = "Ambiente di deploy (prod, dev)"
}

variable "vpc_cidr" {
  type        = string
  description = "Blocco CIDR della VPC"
}

variable "subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  description = "Mappa delle subnet"
}

variable "common_tags" {
  type        = map(string)
  description = "Tag generati dal modulo tags"
}