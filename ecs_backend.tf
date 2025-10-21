# ============================================================================== 
# Security Groups (Backend - internal/public)
# ==============================================================================

locals {
  backend_public_fqdn = "${var.backend_public_subdomain}.${var.domain_name}"
}

// Removed: internal backend ALB security group

resource "aws_security_group" "alb_backend_public" {
  name        = "${var.project_name}-${var.environment}-alb-backend-public-sg"
  description = "ALB SG for backend (public)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-alb-backend-public-sg" }
}

resource "aws_security_group" "ecs_backend" {
  name        = "${var.project_name}-${var.environment}-ecs-backend-sg"
  description = "ECS service SG for backend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App from Backend ALB"
    from_port       = var.backend_container_port
    to_port         = var.backend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_backend_public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-ecs-backend-sg" }
}

# ==============================================================================
# RDS Security Group (allow from backend ECS only)
# ==============================================================================

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "RDS SG for PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS Backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-rds-sg" }
}

# ==============================================================================
# Redis Security Group (allow from backend ECS only)
# ==============================================================================

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "ElastiCache Redis SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from ECS Backend"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-redis-sg" }
}

// Removed: internal backend ALB and its target group

resource "aws_lb_target_group" "backend_public" {
  name_prefix = "wb-"
  port        = var.backend_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = var.backend_health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  lifecycle { create_before_destroy = true }
}

# ==============================================================================
# Public ALB (Backend API)
# ==============================================================================

resource "aws_lb" "backend_public" {
  name               = "${var.project_name}-${var.environment}-backend-api-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_backend_public.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout       = 60

  tags = { Name = "${var.project_name}-${var.environment}-backend-public-alb" }
}

resource "aws_lb_listener" "backend_public_http_redirect" {
  load_balancer_arn = aws_lb.backend_public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_lb_listener" "backend_public_https" {
  load_balancer_arn = aws_lb.backend_public.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.backend_public.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_public.arn
  }

  depends_on = [aws_acm_certificate_validation.backend_public]
  lifecycle  { create_before_destroy = true }
}

# ==============================================================================
# ACM (for Public API domain)
# ==============================================================================

resource "aws_acm_certificate" "backend_public" {
  domain_name       = local.backend_public_fqdn
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-public-cert"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_route53_record" "backend_public_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.backend_public.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.public.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "backend_public" {
  certificate_arn         = aws_acm_certificate.backend_public.arn
  validation_record_fqdns = [for record in aws_route53_record.backend_public_cert_validation : record.fqdn]
}

// Removed: internal backend ALB HTTP listener

# ==============================================================================
# ECS Cluster / Roles / Logs (Backend)
# ==============================================================================

resource "aws_ecs_cluster" "backend" {
  name = "${var.project_name}-${var.environment}-backend"
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-${var.environment}-backend"
  retention_in_days = 14
}

# 既存のタスク実行ロールを再利用（frontend と共通）

# Secrets Manager 読取権限をタスク実行ロールへ付与
resource "aws_iam_role_policy" "ecs_exec_read_rds_secret" {
  name = "${var.project_name}-${var.environment}-ecs-exec-read-rds-secret"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = [
          (length(var.rds_master_secret_arn) > 0 ? var.rds_master_secret_arn : aws_secretsmanager_secret.rds_master_password[0].arn),
          "${length(var.rds_master_secret_arn) > 0 ? var.rds_master_secret_arn : aws_secretsmanager_secret.rds_master_password[0].arn}*",
          (length(var.redis_auth_secret_arn) > 0 ? var.redis_auth_secret_arn : aws_secretsmanager_secret.redis_auth_token[0].arn),
          "${length(var.redis_auth_secret_arn) > 0 ? var.redis_auth_secret_arn : aws_secretsmanager_secret.redis_auth_token[0].arn}*"
        ]
      }
    ]
  })
}

# ==============================================================================
# Task Role for application (DynamoDB/S3 access etc.)
# ==============================================================================

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DescribeTable"
    ]
    resources = [
      aws_dynamodb_table.primary.arn,
      "${aws_dynamodb_table.primary.arn}/index/*"
    ]
  }

  statement {
    sid    = "S3SnapshotsAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.snapshots.arn,
      "${aws_s3_bucket.snapshots.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_inline" {
  name   = "${var.project_name}-${var.environment}-ecs-task-inline"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

# ==============================================================================
# Task Definition (Backend)
# ==============================================================================

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-${var.environment}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_task_cpu
  memory                   = var.backend_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.backend_container_port
        hostPort      = var.backend_container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = tostring(var.backend_container_port) },
        { name = "DATABASE_URL", value = "postgresql://${var.rds_username}:${jsondecode(data.aws_secretsmanager_secret_version.rds_master_password.secret_string)["password"]}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.rds_db_name}" },
        { name = "DYNAMODB_TABLE_NAME", value = var.dynamodb_table_name },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "REDIS_HOST", value = aws_elasticache_replication_group.redis.primary_endpoint_address },
        { name = "REDIS_PORT", value = "6379" },
        { name = "REDIS_TLS", value = "true" },
        { name = "AWS_S3_BUCKET_NAME", value = aws_s3_bucket.snapshots.bucket },
        { name = "COGNITO_ISSUER", value = var.cognito_issuer },
        { name = "SKIP_AUTH", value = tostring(var.skip_auth) },
        { name = "CORS_ORIGINS", value = (length(var.backend_cors_origins) > 0 ? var.backend_cors_origins : "https://${var.frontend_subdomain}.${var.domain_name}") }
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${length(var.rds_master_secret_arn) > 0 ? var.rds_master_secret_arn : aws_secretsmanager_secret.rds_master_password[0].arn}:password::" },
        { name = "REDIS_AUTH_TOKEN", valueFrom = "${length(var.redis_auth_secret_arn) > 0 ? var.redis_auth_secret_arn : aws_secretsmanager_secret.redis_auth_token[0].arn}:token::" }
      ]
    }
  ])
}

# ==============================================================================
# Task Definition (Backend - Migration One-off)
# ==============================================================================

resource "aws_ecs_task_definition" "backend_migration" {
  family                   = "${var.project_name}-${var.environment}-backend-migration"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_task_cpu
  memory                   = var.backend_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.backend_container_port
        hostPort      = var.backend_container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "migrate"
        }
      }
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = tostring(var.backend_container_port) },
        { name = "DATABASE_URL", value = "postgresql://${var.rds_username}:${jsondecode(data.aws_secretsmanager_secret_version.rds_master_password.secret_string)["password"]}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.rds_db_name}" },
        { name = "DYNAMODB_TABLE_NAME", value = var.dynamodb_table_name },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "REDIS_HOST", value = aws_elasticache_replication_group.redis.primary_endpoint_address },
        { name = "REDIS_PORT", value = "6379" },
        { name = "REDIS_TLS", value = "true" },
        { name = "AWS_S3_BUCKET_NAME", value = aws_s3_bucket.snapshots.bucket },
        { name = "COGNITO_ISSUER", value = var.cognito_issuer },
        { name = "SKIP_AUTH", value = tostring(var.skip_auth) },
        { name = "CORS_ORIGINS", value = (length(var.backend_cors_origins) > 0 ? var.backend_cors_origins : "https://${var.frontend_subdomain}.${var.domain_name}") }
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${length(var.rds_master_secret_arn) > 0 ? var.rds_master_secret_arn : aws_secretsmanager_secret.rds_master_password[0].arn}:password::" },
        { name = "REDIS_AUTH_TOKEN", valueFrom = "${length(var.redis_auth_secret_arn) > 0 ? var.redis_auth_secret_arn : aws_secretsmanager_secret.redis_auth_token[0].arn}:token::" }
      ]
      command = ["sh", "-lc", "prisma migrate deploy"]
    }
  ])
}

# ==============================================================================
# ECS Service (Backend)
# ==============================================================================

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-${var.environment}-backend"
  cluster         = aws_ecs_cluster.backend.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_backend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_public.arn
    container_name   = "backend"
    container_port   = var.backend_container_port
  }

  depends_on = [aws_lb_listener.backend_public_https]
}


