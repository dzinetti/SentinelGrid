aws_region   = "eu-west-1"
project_name = "terraform-junior"
environment  = "test"
owner        = "junior_2"

vpc_cidr = "10.40.0.0/16"

subnets = {
  app = {
    cidr = "10.40.1.0/24"
    az   = "eu-west-1a"
  }
  db = {
    cidr = "10.40.2.0/24"
    az   = "eu-west-1b"
  }
}

