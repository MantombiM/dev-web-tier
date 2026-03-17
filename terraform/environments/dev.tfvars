aws_region         = "us-east-1"
environment        = "dev"
service_name       = "rewards"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
instance_type      = "t4g.nano"
min_size           = 1
max_size           = 3
desired_capacity   = 2
alarm_email        = "mimimanqele13@gmail.com"

common_tags = {
  environment = "dev"
  service     = "rewards"
  owner       = "Mantombi Manqele"
  cost_center = "payments"
  managed_by  = "terraform"
  project     = "neal-street-assessment"
}
