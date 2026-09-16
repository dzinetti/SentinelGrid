output "vpc_id" {
  value       = aws_vpc.vpc1.id
  description = "ID della VPC"
}

output "private_subnet_ids" {
  description = "Lista degli ID delle subnet private per EKS"
  value       = [for k, v in aws_subnet.subnet : v.id if can(regex("private", k))]
}

output "public_subnet_ids" {
  description = "Lista degli ID delle subnet pubbliche"
  value       = [for k, v in aws_subnet.subnet : v.id if can(regex("public", k))]
}