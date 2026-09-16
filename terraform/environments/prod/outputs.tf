output "tags_comuni" {
  description = "Tag generati dal modulo tags"
  value       = module.tags.common_tags
}

output "ecr_repository_urls" {
  description = "URL dei repository ECR creati"
  value       = module.ecr.repository_urls
}