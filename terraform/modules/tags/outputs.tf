output "common_tags" {
  description = "Mappa dei tag comuni per l'infrastruttura"
  value = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}