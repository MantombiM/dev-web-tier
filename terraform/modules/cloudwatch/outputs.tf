output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = aws_sns_topic.cloudwatch_alarms.arn
}

output "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5xx errors alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx_errors.arn
}

output "unhealthy_targets_alarm_arn" {
  description = "ARN of the unhealthy targets alarm"
  value       = aws_cloudwatch_metric_alarm.unhealthy_targets.arn
}

output "high_cpu_alarm_arn" {
  description = "ARN of the high CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu_utilization.arn
}
