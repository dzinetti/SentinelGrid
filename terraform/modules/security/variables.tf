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