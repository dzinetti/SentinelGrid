variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "terraform-junior"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "test"], var.environment)
    error_message = "environment deve essere dev oppure test."
  }
}

variable "owner" { type = string }
variable "vpc_cidr" { type = string }

variable "subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "rules" {
  type = map(object({
    from_port   = number
    to_port     = number
    ip_protocol = string
    description = string
  }))
}