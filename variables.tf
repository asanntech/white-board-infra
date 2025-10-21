# ==============================================================================
# General Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "white-board"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ==============================================================================
# Network Variables
# ==============================================================================

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/20"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost optimization)"
  type        = bool
  default     = true
}

# ==============================================================================
# Route53 / DNS Variables
# ==============================================================================

variable "domain_name" {
  description = "Root domain name managed in Route53 (e.g. example.com)"
  type        = string
}

variable "frontend_subdomain" {
  description = "Subdomain for frontend (e.g. app)"
  type        = string
  default     = "white-board"
}

# Public DNS for backend API endpoint
variable "backend_public_subdomain" {
  description = "Public subdomain name for backend API (e.g. api)"
  type        = string
  default     = "api"
}

# Private DNS for internal backend endpoint
variable "private_domain_name" {
  description = "Private hosted zone domain (only resolvable inside VPC)"
  type        = string
  default     = "internal.white-board.dev"
}

variable "backend_private_subdomain" {
  description = "Private subdomain name for backend (e.g. api)"
  type        = string
  default     = "api"
}

variable "enable_cdn" {
  description = "Enable CloudFront distribution for frontend"
  type        = bool
  default     = true
}

variable "frontend_alb_dns_name" {
  description = "Public DNS name of the frontend ALB used as CloudFront origin"
  type        = string
}

# エッジ拠点の範囲と価格設定の関係
variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}

# ==============================================================================
# Frontend ECS/ALB Variables
# ==============================================================================

variable "frontend_container_image" {
  description = "Container image for the frontend app"
  type        = string
  default     = "nginx:alpine"
}

variable "frontend_image_tag" {
  description = "Tag for the frontend image stored in ECR (e.g. latest, v1.2.3)"
  type        = string
  default     = "latest"
}

variable "frontend_container_port" {
  description = "Container port exposed by the frontend app"
  type        = number
  default     = 3000
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

variable "frontend_task_cpu" {
  description = "Fargate task CPU units for frontend"
  type        = number
  default     = 256
}

variable "frontend_task_memory" {
  description = "Fargate task memory (MiB) for frontend"
  type        = number
  default     = 512
}

variable "frontend_health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/"
}

variable "enable_ipv6_alias" {
  description = "Create AAAA alias record to CloudFront"
  type        = bool
  default     = true
}

# ==============================================================================
# Backend ECS/ALB Variables
# ==============================================================================

variable "backend_container_port" {
  description = "Container port exposed by the backend app"
  type        = number
  default     = 4000
}

variable "backend_image_tag" {
  description = "Tag for the backend image stored in ECR (e.g. latest, v1.2.3)"
  type        = string
  default     = "latest"
}

variable "backend_desired_count" {
  description = "Desired number of backend tasks"
  type        = number
  default     = 2
}

variable "backend_task_cpu" {
  description = "Fargate task CPU units for backend"
  type        = number
  default     = 256
}

variable "backend_task_memory" {
  description = "Fargate task memory (MiB) for backend"
  type        = number
  default     = 512
}

variable "backend_health_check_path" {
  description = "Health check path for backend ALB target group"
  type        = string
  default     = "/health"
}

# Optional: override CORS allowed origins for backend (comma-separated)
variable "backend_cors_origins" {
  description = "Comma-separated list of allowed CORS origins for backend API"
  type        = string
  default     = ""
}

# Cognito/OpenID issuer for backend auth
variable "cognito_issuer" {
  description = "OIDC issuer URL for Cognito (e.g. https://cognito-idp.ap-northeast-1.amazonaws.com/xxxx)"
  type        = string
  default     = ""
}

# Toggle to skip auth (for development/testing)
variable "skip_auth" {
  description = "Whether to skip auth checks (dev only)"
  type        = bool
  default     = false
}

# ==============================================================================
# RDS (PostgreSQL) Variables
# ==============================================================================

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "17"
}

# ==============================================================================
# DynamoDB Variables
# ==============================================================================

variable "dynamodb_table_name" {
  description = "Primary DynamoDB table name"
  type        = string
  default     = "drawings"
}

# ==============================================================================
# Redis (ElastiCache) Variables
# ==============================================================================

variable "redis_node_type" {
  description = "ElastiCache node instance class"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_replicas_per_node_group" {
  description = "Number of replicas per node group (0 for single node)"
  type        = number
  default     = 0
}

variable "redis_auth_secret_arn" {
  description = "Existing Secrets Manager ARN for Redis auth token (optional)"
  type        = string
  default     = ""
}

variable "dynamodb_billing_mode" {
  description = "Billing mode for DynamoDB (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_ttl_attribute" {
  description = "TTL attribute name (empty to disable)"
  type        = string
  default     = ""
}

variable "dynamodb_enable_stream" {
  description = "Enable DynamoDB stream"
  type        = bool
  default     = false
}

variable "dynamodb_stream_view_type" {
  description = "Stream view type (e.g., NEW_AND_OLD_IMAGES)"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Max autoscaled storage in GiB"
  type        = number
  default     = 100
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "rds_db_name" {
  description = "Database name"
  type        = string
  default     = "whiteboard"
}

variable "rds_username" {
  description = "Master username"
  type        = string
  default     = "dev"
}

variable "rds_backup_retention" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "Mon:20:00-Mon:21:00"
}

variable "rds_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "19:00-20:00"
}

# 既存Secrets利用時は ARN を指定（指定があれば新規作成しない）
variable "rds_master_secret_arn" {
  description = "Existing Secrets Manager ARN for RDS master password (optional)"
  type        = string
  default     = ""
}

# ==============================================================================
# S3 (Snapshots) Variables
# ==============================================================================

variable "snapshots_bucket_name" {
  description = "S3 bucket name for snapshots"
  type        = string
  default     = "white-board-snapshots-dev"
}

