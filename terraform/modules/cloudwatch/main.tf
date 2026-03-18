resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.service_name}-${var.environment}-cloudwatch-alarms"

  tags = {
    Name        = "${var.service_name}-${var.environment}-cloudwatch-alarms"
    Environment = var.environment
    Service     = var.service_name
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "cloudwatch_alarms_email" {
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.service_name}-${var.environment}-alb-5xx-errors"
  alarm_description   = "Alert when ALB returns more than 50 5xx errors in 10 minutes - indicates sustained backend service issues"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  tags = {
    Name        = "${var.service_name}-${var.environment}-alb-5xx-errors"
    Environment = var.environment
    Service     = var.service_name
    ManagedBy   = "terraform"
    AlarmType   = "availability"
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.service_name}-${var.environment}-unhealthy-targets"
  alarm_description   = "Alert when targets remain unhealthy for 5 consecutive checks - indicates persistent instance health failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  tags = {
    Name        = "${var.service_name}-${var.environment}-unhealthy-targets"
    Environment = var.environment
    Service     = var.service_name
    ManagedBy   = "terraform"
    AlarmType   = "health"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name          = "${var.service_name}-${var.environment}-high-cpu"
  alarm_description   = "Alert when average CPU utilization exceeds 90% for 25 minutes - indicates sustained resource constraint"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = "${var.service_name}-${var.environment}-asg"
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  tags = {
    Name        = "${var.service_name}-${var.environment}-high-cpu"
    Environment = var.environment
    Service     = var.service_name
    ManagedBy   = "terraform"
    AlarmType   = "performance"
  }
}
