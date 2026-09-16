output "common_tags" {
  description = "Mappa dei tag comuni per l'infrastruttura"
  value = {
    CentroDiCosto = var.CentroDiCosto
    Environment = var.environment
  }
}