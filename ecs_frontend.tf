# ==============================================================================
# Security Groups
# ==============================================================================

resource "aws_security_group" "alb_frontend" {
  name        = "${var.project_name}-${var.environment}-alb-frontend-sg"
  description = "ALB SG for frontend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-frontend-sg"
  }
}

resource "aws_security_group" "ecs_frontend" {
  name        = "${var.project_name}-${var.environment}-ecs-frontend-sg"
  description = "ECS service SG for frontend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App from ALB"
    from_port       = var.frontend_container_port
    to_port         = var.frontend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-frontend-sg"
  }
}

# ==============================================================================
# ALB
# ==============================================================================

resource "aws_lb" "frontend" {
  name               = "${var.project_name}-${var.environment}-frontend-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_frontend.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout       = 60

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend-alb"
  }
}

resource "aws_lb_target_group" "frontend" {
  name_prefix = "wb-"
  port        = var.frontend_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = var.frontend_health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# ECS Cluster / Roles / Logs
# ==============================================================================

resource "aws_ecs_cluster" "frontend" {
  name = "${var.project_name}-${var.environment}-frontend"
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-${var.environment}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-${var.environment}-frontend"
  retention_in_days = 14
}

# ==============================================================================
# Task Definition
# ==============================================================================

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-${var.environment}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.frontend_task_cpu
  memory                   = var.frontend_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:${var.frontend_image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.frontend_container_port
        hostPort      = var.frontend_container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.frontend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ==============================================================================
# ECS Service
# ==============================================================================

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-${var.environment}-frontend"
  cluster         = aws_ecs_cluster.frontend.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_frontend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = var.frontend_container_port
  }

  depends_on = [aws_lb_listener.frontend_http]
}


