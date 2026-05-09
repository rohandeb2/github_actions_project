environment             = "prod"
aws_region              = "us-east-1"
project                 = "bankapp"

# VPC
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS
cluster_version         = "1.29"
node_instance_types     = ["t3.medium"]
node_group_min_size     = 2
node_group_max_size     = 10
node_group_desired_size = 3

# RDS
db_instance_class        = "db.t3.medium"
db_name                  = "bankdb"
db_allocated_storage     = 20
db_max_allocated_storage = 100

# db_username and db_password are passed via environment variables:
# TF_VAR_db_username and TF_VAR_db_password
# Never put credentials in tfvars files
