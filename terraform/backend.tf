terraform {
  backend "s3" {
    bucket         = "rewards-terraform-state-038308560390"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "rewards-terraform-locks"
    encrypt        = true
  }
}
