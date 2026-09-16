# 1. EKS Cluster (Control Plane)
resource "aws_eks_cluster" "main" {
  name     = "sentinelgrid-eks-cluster"
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [var.cluster_sg_id]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "sentinelgrid-eks-cluster"
    }
  )
}

# 2. EKS Managed Node Group (Worker Nodes)
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "sentinelgrid-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  tags = merge(
    var.common_tags,
    {
      Name = "sentinelgrid-node-group"
    }
  )
}