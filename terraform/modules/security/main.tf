# ==========================================
# 1. SECURITY GROUPS
# ==========================================

# Security Group per il Control Plane EKS
resource "aws_security_group" "cluster" {
  name        = "sentinelgrid-${var.environment}-cluster-sg"
  description = "Security Group per il Control Plane di EKS"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "sentinelgrid-${var.environment}-cluster-sg"
  })
}

# Security Group per i Worker Nodes
resource "aws_security_group" "nodes" {
  name        = "sentinelgrid-${var.environment}-nodes-sg"
  description = "Security Group per i Worker Nodes di EKS"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "sentinelgrid-${var.environment}-nodes-sg"
  })
}

# Regole generali di traffico in uscita
resource "aws_vpc_security_group_egress_rule" "cluster_all" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow outbound traffic from cluster"
}

resource "aws_vpc_security_group_egress_rule" "nodes_all" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow outbound traffic from nodes"
}

# 1. Permetti ai nodi worker di comunicare tra loro su tutte le porte
resource "aws_vpc_security_group_ingress_rule" "nodes_internal" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
  description                  = "Allow nodes to communicate with each other"
}

# 2. Permetti ai nodi worker di ricevere traffico dal Control Plane
resource "aws_vpc_security_group_ingress_rule" "nodes_from_cluster" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.cluster.id
  ip_protocol                  = "-1"
  description                  = "Allow worker nodes to receive traffic from control plane"
}

# 3. Permetti al Control Plane di ricevere traffico dai nodi worker
resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
  description                  = "Allow control plane to receive traffic from worker nodes"
}
# ==========================================
# 2. RUOLI E POLICY IAM PER EKS
# ==========================================

# Ruolo IAM per il Control Plane (Cluster EKS)
resource "aws_iam_role" "cluster" {
  name = "sentinelgrid-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "sentinelgrid-${var.environment}-eks-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Ruolo IAM per i Worker Nodes (Node Group)
resource "aws_iam_role" "node_group" {
  name = "sentinelgrid-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "sentinelgrid-${var.environment}-eks-node-role"
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# ==========================================
# 3. RUOLO IAM PER EBS CSI DRIVER (IRSA)
# ==========================================

data "aws_iam_policy_document" "ebs_csi_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "AmazonEKS_EBS_CSI_DriverRole_SentinelGrid"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json

  tags = merge(var.common_tags, {
    Name = "AmazonEKS_EBS_CSI_DriverRole_SentinelGrid"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}