module "network" {
  source = "./modules/network"

  vpc_cidr           = var.vpc_cidr
  environment        = var.environment
  service_name       = var.service_name
  availability_zones = var.availability_zones
}

module "iam" {
  source = "./modules/iam"

  environment  = var.environment
  service_name = var.service_name
}

module "loadbalancer" {
  source = "./modules/loadbalancer"

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  environment           = var.environment
  service_name          = var.service_name
}

module "compute" {
  source = "./modules/compute"

  instance_type         = var.instance_type
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.desired_capacity
  private_subnet_id     = module.network.private_subnet_id
  app_security_group_id = module.network.app_security_group_id
  instance_profile_name = module.iam.instance_profile_name
  target_group_arns     = [module.loadbalancer.target_group_arn]
  environment           = var.environment
  service_name          = var.service_name
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment              = var.environment
  service_name             = var.service_name
  alb_arn_suffix          = module.loadbalancer.alb_arn_suffix
  target_group_arn_suffix = module.loadbalancer.target_group_arn_suffix
  alarm_email             = var.alarm_email
}
