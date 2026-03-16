output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "instance_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.ec2_instance_role.arn
}

output "instance_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.ec2_instance_role.name
}
