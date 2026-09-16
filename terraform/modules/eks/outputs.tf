output "cluster_name" {
  description = "Nome del cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint API del cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Dati CA del cluster per la configurazione di kubectl"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}