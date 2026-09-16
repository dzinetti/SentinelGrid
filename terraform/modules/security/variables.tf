variable "vpc_id" {
    type = string
}

variable "vpc_cidr"{
    type = string
}

variable rules{
    type = map(object({
    from_port = number
    to_port    = number
    ip_protocol =string
    description = string
  }))
}

variable "common_tags" {
  type = map(string)
}

variable "project_name" { type = string }
variable "environment"  { type = string }