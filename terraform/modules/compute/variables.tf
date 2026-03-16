variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
}

variable "private_subnet_id" {
  description = "ID of the private subnet"
  type        = string
}

variable "app_security_group_id" {
  description = "ID of the application security group"
  type        = string
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile"
  type        = string
}

variable "target_group_arns" {
  description = "List of target group ARNs"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Service name"
  type        = string
}
