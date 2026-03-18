variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "service_name" {
  description = "Service name for resource naming"
  type        = string
  default     = "rewards"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones for resource deployment"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones must be specified for ALB."
  }
}

variable "instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t4g.nano"
}

variable "min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.min_size >= 1
    error_message = "Minimum size must be at least 1."
  }
}

variable "max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 3

  validation {
    condition     = var.max_size >= 1
    error_message = "Maximum size must be at least 1."
  }
}

variable "desired_capacity" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_capacity >= 1
    error_message = "Desired capacity must be at least 1."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    environment = "dev"
    service     = "rewards"
    owner       = "candidate"
    cost_center = "payments"
    managed_by  = "terraform"
  }
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alarm_email))
    error_message = "Alarm email must be a valid email address."
  }
}
