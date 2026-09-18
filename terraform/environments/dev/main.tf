# 1. Modulo TAGS
module "tags" {
  source = "../../modules/tags"

  CentroDiCosto = var.CentroDiCosto
  environment   = var.environment
}

# 2. Modulo ECR 
module "ecr" {
  source = "../../modules/ecr"

  common_tags = module.tags.common_tags
}

# 3. Modulo VPC 
module "vpc" {
  source = "../../modules/vpc"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  subnets     = var.subnets
  common_tags = module.tags.common_tags
}

# 4. Modulo SECURITY
module "security" {
  source = "../../modules/security"

  environment       = var.environment
  common_tags       = module.tags.common_tags
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

# 5. Modulo EKS
module "eks" {
  source = "../../modules/eks"

  common_tags      = module.tags.common_tags
  private_subnets  = module.vpc.private_subnet_ids
  cluster_sg_id    = module.security.cluster_sg_id
  cluster_role_arn = module.security.cluster_role_arn
  node_role_arn    = module.security.node_role_arn
  ebs_csi_role_arn = module.security.ebs_csi_role_arn

  # Valori dinamici ottenuti da data.tf
  codepipeline_role_arn = data.aws_iam_role.codepipeline.arn
  codebuild_role_arn    = data.aws_iam_role.codebuild.arn
}