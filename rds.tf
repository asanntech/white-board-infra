# ==============================================================================
# RDS: PostgreSQL (Single-AZ default, Multi-AZ optional)
# ==============================================================================

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.project_name}-${var.environment}-postgres"
  engine                  = "postgres"
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  db_subnet_group_name    = aws_db_subnet_group.postgres.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  allocated_storage       = var.rds_allocated_storage
  max_allocated_storage   = var.rds_max_allocated_storage
  storage_type            = "gp3"
  multi_az                = var.rds_multi_az
  username                = var.rds_username
  password                = jsondecode(data.aws_secretsmanager_secret_version.rds_master_password.secret_string)["password"]
  db_name                 = var.rds_db_name
  port                    = 5432
  publicly_accessible     = false
  storage_encrypted       = true
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = var.rds_backup_retention
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window

  apply_immediately = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
  }
}

# ==============================================================================
# Secrets Manager: RDS Master Password
# ==============================================================================

resource "random_password" "rds_master" {
  length  = 24
  special = true
  # RDS パスワード制約に合わせて @ / " を含めない
  override_special = "!#%^*-_+="
}

locals {
  use_existing_rds_secret = length(var.rds_master_secret_arn) > 0
}

resource "aws_secretsmanager_secret" "rds_master_password" {
  count = local.use_existing_rds_secret ? 0 : 1
  name  = "${var.project_name}/${var.environment}/rds/master"
}

resource "aws_secretsmanager_secret_version" "rds_master_password" {
  count        = local.use_existing_rds_secret ? 0 : 1
  secret_id    = aws_secretsmanager_secret.rds_master_password[0].id
  secret_string = jsonencode({ password = random_password.rds_master.result })
}

data "aws_secretsmanager_secret_version" "rds_master_password" {
  secret_id = local.use_existing_rds_secret ? var.rds_master_secret_arn : aws_secretsmanager_secret.rds_master_password[0].arn
  # When creating a new secret, the reference above already creates an implicit dependency.
}


