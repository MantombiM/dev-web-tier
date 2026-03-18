data "aws_ami" "amazon_linux_2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_launch_template" "main" {
  name_prefix   = "${var.environment}-${var.service_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023_arm64.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
    delete_on_termination       = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tpl", {
    environment  = var.environment
    service_name = var.service_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-${var.service_name}-instance"
      environment = var.environment
      service     = var.service_name
      managed_by  = "terraform"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment}-${var.service_name}-volume"
      environment = var.environment
      service     = var.service_name
      managed_by  = "terraform"
    }
  }

  tags = {
    Name        = "${var.environment}-${var.service_name}-lt"
    environment = var.environment
    service     = var.service_name
    managed_by  = "terraform"
  }
}

resource "aws_autoscaling_group" "main" {
  name                      = "${var.environment}-${var.service_name}-asg"
  vpc_zone_identifier       = [var.private_subnet_id]
  target_group_arns         = var.target_group_arns
  health_check_type         = "ELB"
  health_check_grace_period = 600

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-${var.service_name}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "service"
    value               = var.service_name
    propagate_at_launch = true
  }

  tag {
    key                 = "managed_by"
    value               = "terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "AnsibleManaged"
    value               = "true"
    propagate_at_launch = true
  }
}
