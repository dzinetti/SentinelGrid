# --- Output richiesti da specifica ---

output "vpc_id" {
  description = "ID della VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "ID delle subnet private"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "ID delle subnet pubbliche"
  value       = module.vpc.public_subnet_ids
}

output "ecr_repository_urls" {
  description = "URL dei repository ECR creati"
  value       = module.ecr.repository_urls
}

output "eks_cluster_name" {
  description = "Nome del cluster EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint API del cluster EKS"
  value       = module.eks.cluster_endpoint
}   