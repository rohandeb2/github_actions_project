locals {
  name = "${var.project}-${var.environment}"
}

# ── DB Subnet Group ───────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name        = "${local.name}-db-subnet-group"
  description = "Subnet group for ${local.name} RDS"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}

# ── KMS Key for RDS encryption ────────────────────────────────────────
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${local.name}-rds-kms"
  }
}

# ── RDS Parameter Group ───────────────────────────────────────────────
resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name}-postgres16"
  family = "postgres16"

  # Security hardening parameters
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"   # log queries taking > 1s
  }

  tags = {
    Name = "${local.name}-postgres-params"
  }
}

# ── RDS Instance ──────────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${local.name}-postgres"

  # Engine
  engine               = "postgres"
  engine_version       = "16.1"
  instance_class       = var.db_instance_class

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false   # NEVER public in prod

  # High availability
  multi_az = true

  # Backups
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  delete_automated_backups  = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-final-snapshot"

  # Monitoring
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  # Hardening
  parameter_group_name = aws_db_parameter_group.postgres.name
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  deletion_protection        = true   # prevents accidental deletion in prod

  tags = {
    Name = "${local.name}-postgres"
  }
}

# ── IAM Role for Enhanced Monitoring ─────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
