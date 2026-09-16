output "vpc_id" {
  value = aws_vpc.vpc1.id
}

output "subnet_ids" {
  value = { for name, subnet in aws_subnet.subnet : name => subnet.id }
}

output "vpc_name" {
  value       = aws_vpc.vpc1.tags["Name"]
  description = "Nome della VPC derivato dai tag"
}