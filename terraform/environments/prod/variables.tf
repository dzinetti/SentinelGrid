variable "aws_region" {
  type        = string
  description = "Regione AWS di deploy"
  default     = "eu-west-1"
}

variable "CentroDiCosto" {
  type        = string
  description = "Centro di costo da assegnare ai tag"
  default     = "CloudLab_Campus"
}

variable "environment" {
  type        = string
  description = "Ambiente di deploy (dev,prod)"
}

/*
variable "vpc_cidr" {
  type        = string
  description = "Blocco CIDR per la VPC"
}

variable "subnets" {
  type = map(object({
    cidr   = string
    az     = string
    public = bool
  }))
  description = "Mappa delle subnet pubbliche e private"
}
*/