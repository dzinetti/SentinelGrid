output "cluster_sg_id" {
  description = "ID del Security Group del Control Plane"
  value       = aws_security_group.cluster.id
}

output "nodes_sg_id" {
  description = "ID del Security Group dei Worker Nodes"
  value       = aws_security_group.nodes.id
}

output "cluster_role_arn" {
  description = "ARN del ruolo IAM per il Control Plane EKS"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN del ruolo IAM per i Worker Nodes EKS"
  value       = aws_iam_role.node_group.arn
}