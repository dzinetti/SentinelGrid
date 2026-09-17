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

# NUOVI OUTPUTS PER OIDC
output "oidc_provider_arn" {
  description = "ARN dell'OIDC Provider per IRSA"
  value       = aws_iam_openid_connect_provider.main.arn
}

output "oidc_provider_url" {
  description = "URL dell'OIDC Issuer senza https://"
  value       = replace(aws_iam_openid_connect_provider.main.url, "https://", "")
}