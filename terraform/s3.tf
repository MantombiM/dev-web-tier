# resource "aws_s3_bucket" "ansible_ssm" {
#   bucket = "rewards-ansible-ssm-${var.environment}"

#   tags = merge(
#     var.common_tags,
#     {
#       Name        = "rewards-ansible-ssm-${var.environment}"
#       Description = "Ansible SSM Session Manager file transfer bucket"
#     }
#   )
# }

# resource "aws_s3_bucket_versioning" "ansible_ssm" {
#   bucket = aws_s3_bucket.ansible_ssm.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_ssm" {
#   bucket = aws_s3_bucket.ansible_ssm.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "ansible_ssm" {
#   bucket = aws_s3_bucket.ansible_ssm.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_bucket_lifecycle_configuration" "ansible_ssm" {
#   bucket = aws_s3_bucket.ansible_ssm.id

#   rule {
#     id     = "cleanup-temp-files"
#     status = "Enabled"

#     expiration {
#       days = 7
#     }

#     noncurrent_version_transition {
#       noncurrent_days = 30
#       storage_class   = "GLACIER"
#     }
#   }
# }
