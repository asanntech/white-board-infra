# ==============================================================================
# ElastiCache Redis (auth token stored in Secrets Manager)
# ==============================================================================

resource "random_password" "redis_auth" {
  length           = 32
  special          = true
  override_special = "!#%^*-_+="
}

locals {
  use_existing_redis_secret = length(var.redis_auth_secret_arn) > 0
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  count = local.use_existing_redis_secret ? 0 : 1
  name  = "${var.project_name}/${var.environment}/redis/auth"
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  count         = local.use_existing_redis_secret ? 0 : 1
  secret_id     = aws_secretsmanager_secret.redis_auth_token[0].id
  secret_string = jsonencode({ token = random_password.redis_auth.result })
}

data "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id = local.use_existing_redis_secret ? var.redis_auth_secret_arn : aws_secretsmanager_secret.redis_auth_token[0].arn
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-${var.environment}-redis"
  description                = "Redis for ${var.project_name}-${var.environment}"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.redis_node_type
  replicas_per_node_group    = var.redis_replicas_per_node_group
  automatic_failover_enabled = var.redis_replicas_per_node_group > 0
  multi_az_enabled           = var.redis_replicas_per_node_group > 0
  port                       = 6379

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = jsondecode(data.aws_secretsmanager_secret_version.redis_auth_token.secret_string)["token"]

  security_group_ids = [aws_security_group.redis.id]
  subnet_group_name  = aws_elasticache_subnet_group.redis.name

  maintenance_window = "sun:19:00-sun:20:00"

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis"
    Project     = var.project_name
    Environment = var.environment
  }
}


