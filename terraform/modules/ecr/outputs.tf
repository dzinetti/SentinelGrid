output "repository_urls" {
  description = "Mappa delle URL dei repository ECR creati"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}