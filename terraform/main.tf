module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security_groups" {
  source = "./modules/security-groups"

  project     = var.project
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

module "eks" {
  source = "./modules/eks"

  project                 = var.project
  environment             = var.environment
  cluster_version         = var.cluster_version
  private_subnet_ids      = module.vpc.private_subnet_ids
  cluster_sg_id           = module.security_groups.eks_cluster_sg_id
  node_instance_types     = var.node_instance_types
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size
}

module "rds" {
  source = "./modules/rds"

  project                  = var.project
  environment              = var.environment
  private_subnet_ids       = module.vpc.private_subnet_ids
  rds_sg_id                = module.security_groups.rds_sg_id
  db_instance_class        = var.db_instance_class
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
}
