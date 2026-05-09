variable "project"                  { type = string }
variable "environment"              { type = string }
variable "private_subnet_ids"       { type = list(string) }
variable "rds_sg_id"                { type = string }
variable "db_instance_class"        { type = string }
variable "db_name"                  { type = string }
variable "db_username"              { type = string; sensitive = true }
variable "db_password"              { type = string; sensitive = true }
variable "db_allocated_storage"     { type = number }
variable "db_max_allocated_storage" { type = number }
