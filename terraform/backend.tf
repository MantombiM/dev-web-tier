terraform {
  backend "s3" {
    # Backend configuration will be provided via backend config file or CLI
    # Example:
    # bucket         = "rewards-terraform-state-dev"
    # key            = "dev/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "rewards-terraform-locks"
    # encrypt        = true
  }
}
