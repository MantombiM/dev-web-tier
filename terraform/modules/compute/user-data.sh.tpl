#!/bin/bash
set -e

yum update -y

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

yum install -y python3 python3-pip

INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d ' ' -f 2 | sed 's/[a-z]$//')

aws ec2 create-tags \
  --region $REGION \
  --resources $INSTANCE_ID \
  --tags Key=AnsibleManaged,Value=true
