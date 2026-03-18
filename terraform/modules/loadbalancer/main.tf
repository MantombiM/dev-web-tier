resource "aws_lb" "main" {
  name               = "${var.environment}-${var.service_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.environment}-${var.service_name}-alb"
    environment = var.environment
    service     = var.service_name
    managed_by  = "terraform"
  }
}

resource "aws_lb_target_group" "main" {
  name     = "${var.environment}-${var.service_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.environment}-${var.service_name}-tg"
    environment = var.environment
    service     = var.service_name
    managed_by  = "terraform"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name        = "${var.environment}-${var.service_name}-listener"
    environment = var.environment
    service     = var.service_name
    managed_by  = "terraform"
  }
}
