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

# 2. Modulo VPC 
module "vpc" {
  source = "../../modules/vpc"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  subnets     = var.subnets
  common_tags = module.tags.common_tags
}

# 3. Modulo SECURITY 
module "security" {
  source = "../../modules/security"

  environment = var.environment
  common_tags = module.tags.common_tags
  vpc_id      = module.vpc.vpc_id
}

# 5. Modulo EKS 
module "eks" {
  source = "../../modules/eks"

  common_tags      = module.tags.common_tags

  private_subnets  = module.vpc.private_subnet_ids
  cluster_sg_id    = module.security.cluster_sg_id
  cluster_role_arn = module.security.cluster_role_arn
  node_role_arn    = module.security.node_role_arn
}