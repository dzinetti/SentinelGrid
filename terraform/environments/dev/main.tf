module "tags" {
  source = "../../modules/tags"

  project_name = var.project_name
  environment  = var.environment
  owner        = var.owner
}

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  subnets      = var.subnets
  common_tags  = module.tags.common_tags
}
/*
module "storage" {
  source = "../../modules/storage"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = module.tags.common_tags

  network_name = module.network.vpc_name
}
*/
module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment

  common_tags = module.tags.common_tags

  vpc_cidr = var.vpc_cidr
  vpc_id   = module.vpc.vpc_id
  rules    = var.rules
}
