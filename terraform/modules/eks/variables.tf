variable "common_tags" {
  type        = map(string)
  description = "Tag generati dal modulo tags"
}

variable "private_subnets" {
  type        = list(string)
  description = "Lista degli ID delle subnet private per i nodi EKS"
}

variable "cluster_sg_id" {
  type        = string
  description = "Security Group ID per il Control Plane EKS"
}

variable "cluster_role_arn" {
  type        = string
  description = "ARN del ruolo IAM per il Control Plane EKS"
}

variable "node_role_arn" {
  type        = string
  description = "ARN del ruolo IAM per i Worker Nodes"
}

# NUOVA VARIARIABILE
variable "ebs_csi_role_arn" {
  type        = string
  description = "ARN del ruolo IAM per l'EBS CSI Driver"
}