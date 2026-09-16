variable "project_name" {
  type        = string
  description = "Nome del progetto"
}

variable "environment" {
  type        = string
  description = "Ambiente di deploy (es. dev, test)"
}

variable "owner" {
  type        = string
  description = "Proprietario della risorsa"
}