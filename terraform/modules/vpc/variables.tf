variable "project_name" { type = string }
variable "environment"  { type = string }
variable "vpc_cidr"     { type = string }

variable "subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "common_tags" {
  type = map(string)
}
