# ==============================================================================
# VPC Outputs
# ==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = aws_subnet.database[*].id
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = aws_eip.nat[*].public_ip
}

# ==============================================================================
# Route53 Outputs
# ==============================================================================

output "route53_zone_id" {
  description = "Public hosted zone ID"
  value       = aws_route53_zone.public.zone_id
}

output "route53_name_servers" {
  description = "Public hosted zone name servers"
  value       = aws_route53_zone.public.name_servers
}

# ==============================================================================
# CloudFront Outputs
# ==============================================================================

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

# ==============================================================================
# Frontend ECS/ALB Outputs
# ==============================================================================

output "frontend_alb_dns_name" {
  description = "Frontend public ALB DNS name"
  value       = aws_lb.frontend.dns_name
}

output "frontend_ecs_cluster_name" {
  description = "ECS cluster name for frontend"
  value       = aws_ecs_cluster.frontend.name
}

output "frontend_ecs_service_name" {
  description = "ECS service name for frontend"
  value       = aws_ecs_service.frontend.name
}

# ==============================================================================
# ECR Outputs
# ==============================================================================

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for frontend (use this in CI/CD)"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for backend (use this in CI/CD)"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_backend_repository_arn" {
  description = "ECR repository ARN for backend"
  value       = aws_ecr_repository.backend.arn
}

output "ecr_backend_repository_name" {
  description = "ECR repository name for backend"
  value       = aws_ecr_repository.backend.name
}

# ==============================================================================
# Backend ECS/ALB Outputs
# ==============================================================================

// Removed: backend internal ALB DNS output

output "backend_public_alb_dns_name" {
  description = "Backend public ALB DNS name"
  value       = aws_lb.backend_public.dns_name
}

output "backend_public_api_fqdn" {
  description = "Backend public API FQDN"
  value       = "${var.backend_public_subdomain}.${var.domain_name}"
}

# ==============================================================================
# RDS Outputs
# ==============================================================================

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
}

output "database_url" {
  description = "PostgreSQL DATABASE_URL (includes password)"
  sensitive   = true
  value       = "postgresql://${var.rds_username}:${jsondecode(data.aws_secretsmanager_secret_version.rds_master_password.secret_string)["password"]}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.rds_db_name}"
}

# ==============================================================================
# DynamoDB Outputs
# ==============================================================================

output "dynamodb_table_name" {
  description = "Primary DynamoDB table name"
  value       = aws_dynamodb_table.primary.name
}

# ==============================================================================
# Redis Outputs
# ==============================================================================

output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# ==============================================================================
# S3 Outputs
# ==============================================================================

output "snapshots_bucket_name" {
  description = "Snapshots S3 bucket name"
  value       = aws_s3_bucket.snapshots.bucket
}

output "snapshots_bucket_arn" {
  description = "Snapshots S3 bucket ARN"
  value       = aws_s3_bucket.snapshots.arn
}

output "snapshots_bucket_regional_domain_name" {
  description = "Snapshots S3 bucket regional domain name"
  value       = aws_s3_bucket.snapshots.bucket_regional_domain_name
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = try(aws_elasticache_replication_group.redis.reader_endpoint_address, null)
}

output "redis_auth_secret_arn" {
  description = "Secrets Manager ARN for Redis auth token"
  value       = length(var.redis_auth_secret_arn) > 0 ? var.redis_auth_secret_arn : aws_secretsmanager_secret.redis_auth_token[0].arn
}

output "dynamodb_table_arn" {
  description = "Primary DynamoDB table ARN"
  value       = aws_dynamodb_table.primary.arn
}

output "dynamodb_stream_arn" {
  description = "DynamoDB stream ARN (if enabled)"
  value       = try(aws_dynamodb_table.primary.stream_arn, null)
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "backend_ecs_cluster_name" {
  description = "ECS cluster name for backend"
  value       = aws_ecs_cluster.backend.name
}

output "backend_ecs_service_name" {
  description = "ECS service name for backend"
  value       = aws_ecs_service.backend.name
}

output "migration_security_groups" {
  description = "Security group IDs for migration run-task (use as comma-separated if multiple)."
  value       = aws_security_group.ecs_backend.id
}

output "backend_migration_task_definition_arn" {
  description = "ECS task definition ARN for backend migration (use in CI)"
  value       = aws_ecs_task_definition.backend_migration.arn
}

output "ecr_frontend_repository_arn" {
  description = "ECR repository ARN for frontend"
  value       = aws_ecr_repository.frontend.arn
}

output "ecr_frontend_repository_name" {
  description = "ECR repository name for frontend"
  value       = aws_ecr_repository.frontend.name
}

