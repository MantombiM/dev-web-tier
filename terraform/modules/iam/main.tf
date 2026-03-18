data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.environment}-${var.service_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-${var.service_name}-ec2-role"
    environment = var.environment
    service     = var.service_name
    managed_by  = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_custom_policy" {
  name = "${var.environment}-${var.service_name}-ec2-custom-policy"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/rewards/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::rewards-ansible-ssm-${data.aws_caller_identity.current.account_id}-${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.environment}-${var.service_name}-ec2-profile"
  role = aws_iam_role.ec2_instance_role.name

  tags = {
    Name        = "${var.environment}-${var.service_name}-ec2-profile"
    environment = var.environment
    service     = var.service_name
    managed_by  = "terraform"
  }
}
