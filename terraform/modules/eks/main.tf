# 1. Rileva automaticamente l'identità IAM locale che esegue Terraform
data "aws_caller_identity" "current" {}

# 2. EKS Cluster (Control Plane)
resource "aws_eks_cluster" "main" {
  name     = "sentinelgrid-eks-cluster"
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [var.cluster_sg_id]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "sentinelgrid-eks-cluster"
    }
  )
}

# 3. OIDC Provider per il Cluster EKS (IRSA)
data "tls_certificate" "main" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.main.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.common_tags,
    {
      Name = "sentinelgrid-eks-oidc"
    }
  )
}

# 4. EKS Managed Node Group (Worker Nodes)
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

# 5. Add-on AWS EBS CSI Driver
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_role_arn

  depends_on = [
    aws_eks_node_group.main
  ]
}

# ------------------------------------------------------------------------------
# EKS ACCESS ENTRIES (NATIVE RBAC)
# ------------------------------------------------------------------------------

# Access Entry automatica per l'utente/ruolo IAM locale che esegue Terraform
resource "aws_eks_access_entry" "current_caller" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "current_caller_admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.current_caller.principal_arn

  access_scope {
    type = "cluster"
  }
}

# Access Entry per CodePipeline
resource "aws_eks_access_entry" "codepipeline" {
  count         = var.codepipeline_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.codepipeline_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "codepipeline_admin" {
  count         = var.codepipeline_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.codepipeline[0].principal_arn

  access_scope {
    type = "cluster"
  }
}

# Access Entry per CodeBuild
resource "aws_eks_access_entry" "codebuild" {
  count         = var.codebuild_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.codebuild_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "codebuild_admin" {
  count         = var.codebuild_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.codebuild[0].principal_arn

  access_scope {
    type = "cluster"
  }
}