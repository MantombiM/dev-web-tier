#!/bin/bash
# User data template for EC2 instances
# To be implemented in Phase 3

# This script will:
# - Update system packages
# - Install required dependencies (Python 3, AWS CLI)
# - Configure SSM agent (pre-installed on AL2023)
# - Set up CloudWatch agent
# - Prepare environment for Ansible configuration

set -euo pipefail

# Update system
yum update -y

# Install dependencies
yum install -y python3 python3-pip aws-cli

# Configure instance
echo "Instance initialized at $(date)" > /var/log/user-data.log
