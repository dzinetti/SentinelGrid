aws_region   = "eu-west-1"
project_name = "terraform-junior"
environment  = "test"
owner        = "junior_2"

vpc_cidr = "10.40.0.0/16"

subnets = {
  lb = {
    cidr = "10.40.1.0/24"
    az   = "eu-west-1a"
  }
  clusterIP = {
    cidr = "10.40.2.0/24"
    az   = "eu-west-1a"
  }
  be = {
    cidr = "10.40.3.0/24"
    az   = "eu-west-1a"
  }
}

rules = {
  open8080 = {
    from_port   = 8080
    to_port     = 8080
    ip_protocol = "tcp"
    description = "Porta 8080"
  }
}
