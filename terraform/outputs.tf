output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.loadbalancer.alb_dns_name
}

output "health_endpoint" {
  description = "Health check endpoint URL"
  value       = "http://${module.loadbalancer.alb_dns_name}/health"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.network.private_subnet_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "instance_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = module.iam.instance_role_arn
}

output "ansible_ssm_bucket_name" {
  description = "Name of the S3 bucket for Ansible SSM file transfers"
  value       = aws_s3_bucket.ansible_ssm.id
}
