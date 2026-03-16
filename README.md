# Rewards Web Tier - AWS Infrastructure Automation

**Technical Assessment for Neal Street Technologies**  
**Author**: Mantombi Manqele (mimimanqele13@gmail.com)  
**Position**: Senior Cloud Engineer  
**Date**: March 2026

## Overview

Production-ready AWS infrastructure for the "rewards" web service demonstrating senior-level engineering practices in infrastructure automation, security, and observability. This solution deploys a scalable, cost-optimized development environment using Terraform, Ansible, and GitHub Actions CI/CD.

**Technologies**:
- **Infrastructure**: Terraform 1.7.5
- **Configuration**: Ansible 2.15
- **CI/CD**: GitHub Actions with OIDC
- **Cloud Provider**: AWS (us-east-1)

## Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (us-east-1)                              │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ VPC: 10.0.0.0/16                                                    │   │
│  │                                                                      │   │
│  │  ┌──────────────────┬──────────────────┐                           │   │
│  │  │ AZ: us-east-1a   │ AZ: us-east-1b   │                           │   │
│  │  │                  │                   │                           │   │
│  │  │ PUBLIC SUBNETS                       │                           │   │
│  │  │ ┌──────────────┐ │ ┌──────────────┐ │                           │   │
│  │  │ │     ALB      │◄┼─┼►│     ALB      │ │  Internet ──HTTP:80──►  │   │
│  │  │ │   Port 80    │ │ │ │   Port 80    │ │      (Multi-AZ)         │   │
│  │  │ └──────┬───────┘ │ │ └──────────────┘ │                           │   │
│  │  │        │         │ │                   │                           │   │
│  │  │ ┌──────▼───────┐ │ │                   │                           │   │
│  │  │ │ NAT Gateway  │ │ │   (No NAT)        │                           │   │
│  │  │ │   Egress     │ │ │                   │                           │   │
│  │  │ └──────────────┘ │ │                   │                           │   │
│  │  └──────┬───────────┴──────────────────────┘                           │   │
│  │         │ :8080                                                         │   │
│  │  ┌──────▼─────────────────────────┐                                   │   │
│  │  │ PRIVATE SUBNET (us-east-1a)    │                                   │   │
│  │  │                                 │                                   │   │
│  │  │  ┌──────────────────────────┐  │                                   │   │
│  │  │  │ Auto Scaling Group       │  │                                   │   │
│  │  │  │ Min: 1, Max: 3, Desired: 2│ │                                   │   │
│  │  │  └──────────┬───────────────┘  │                                   │   │
│  │  │             │                   │                                   │   │
│  │  │  ┌──────────▼──────────┐       │                                   │   │
│  │  │  │ EC2: t4g.nano ARM   │       │                                   │   │
│  │  │  │ Health Service:8080 │       │                                   │   │
│  │  │  │ Instance 1          │       │                                   │   │
│  │  │  └─────────────────────┘       │                                   │   │
│  │  │  ┌─────────────────────┐       │                                   │   │
│  │  │  │ EC2: t4g.nano ARM   │       │                                   │   │
│  │  │  │ Health Service:8080 │       │                                   │   │
│  │  │  │ Instance 2          │       │                                   │   │
│  │  │  └─────────────────────┘       │                                   │   │
│  │  └─────────────────────────────────┘                                   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  AWS Managed Services:                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ • CloudWatch Alarms → SNS (Email: mimimanqele13@gmail.com)      │       │
│  │   - ALB 5xx Errors (>10 in 5 min)                               │       │
│  │   - Unhealthy Targets (≥1 for 2 min)                            │       │
│  │   - High CPU (>80% for 10 min)                                  │       │
│  │                                                                   │       │
│  │ • SSM Parameter Store: /rewards/dev/secrets/APP_SECRET          │       │
│  │ • S3: Terraform State + DynamoDB: State Locks                   │       │
│  │ • Systems Manager: Session Manager (No SSH)                     │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│                          CI/CD Pipeline                                      │
│                                                                              │
│  GitHub Actions (OIDC) ──► Terraform Apply ──► Provision Infrastructure   │
│                     └──────► Ansible via SSM ──► Configure Instances        │
│                                                                              │
│  Quality Gates: fmt, validate, plan, ansible-lint                          │
│  Concurrency Control: One deployment at a time                             │
└────────────────────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### Cost Optimization (Target: <$60/month)

**Single-AZ Private Subnet Strategy**:
- Compute tier deployed only in us-east-1a
- Saves ~$32/month vs dual NAT Gateway deployment
- NAT Gateway cost is primary driver in development environments
- Easy migration path to multi-AZ for production

**ARM-Based Instances**:
- t4g.nano (AWS Graviton2) instead of t3.micro
- 20% cost reduction compared to x86 instances
- Amazon Linux 2023 ARM64 with native SSM agent support

**Focused Monitoring**:
- CloudWatch alarms over centralized logging
- Three critical alarms: ALB 5xx errors, unhealthy targets, high CPU
- Cost-effective operational visibility for development

### Security Architecture

**Private Subnet Isolation**:
- All compute resources have no public IP addresses
- Egress through NAT Gateway for package updates and AWS API calls
- Security groups enforce least-privilege network access

**SSM Session Manager**:
- Eliminates SSH key management complexity
- No bastion hosts or VPN required
- All sessions logged to CloudTrail for audit compliance
- Ansible connects via aws_ec2 dynamic inventory

**OIDC for GitHub Actions**:
- No long-lived AWS credentials in GitHub secrets
- Branch-scoped trust policies (main + pull requests only)
- Short-lived tokens with 12-hour maximum session duration

**IMDSv2 Enforcement**:
- Instance Metadata Service v2 required on all EC2 instances
- Mitigates SSRF attacks targeting instance metadata

**Secrets Management**:
- APP_SECRET stored in SSM Parameter Store as SecureString
- EC2 instances fetch secrets at runtime using instance role
- Secrets never appear in Terraform state, CI/CD logs, or source control

### Observability Choice

**CloudWatch Alarms Selected Over Centralized Logs**:

**Rationale**:
- Proactive alerting vs reactive log analysis
- Lower operational overhead in development
- Clear, actionable notifications via SNS email
- Cost-effective ($0.10 per alarm/month)

**Three Critical Alarms**:

| Alarm | Threshold | Evaluation Period | Action |
|-------|-----------|-------------------|--------|
| `rewards-dev-alb-5xx-errors` | >10 errors | 5 minutes (1 datapoint) | Email alert |
| `rewards-dev-unhealthy-targets` | ≥1 unhealthy target | 2 minutes (2 datapoints) | Email alert |
| `rewards-dev-high-cpu` | >80% average | 10 minutes (2 datapoints) | Email alert |

**Production Enhancement Path**: Add CloudWatch Logs, X-Ray tracing, custom metrics

### Hybrid Multi-AZ Strategy

**ALB: Multi-AZ (us-east-1a + us-east-1b)**:
- AWS requirement: ALB must span ≥2 availability zones
- Provides load balancer high availability
- No configuration changes needed for production

**Compute: Single-AZ (us-east-1a)**:
- Cost optimization for development environment
- Acceptable risk profile for non-production workloads

**Production Migration**:
```hcl
# terraform/modules/compute/main.tf
resource "aws_autoscaling_group" "main" {
  vpc_zone_identifier = [
    var.private_subnet_1a_id,
    var.private_subnet_1b_id  # Add second AZ
  ]
  # ... rest of configuration
}
```

## Assumptions Made

### Infrastructure

- **Development Environment**: Single-AZ deployment acceptable for cost savings
- **AWS Account Access**: Appropriate IAM permissions available for infrastructure provisioning
- **HTTP Acceptable**: TLS/HTTPS not required for assessment (production would use ACM + Route53)
- **Email Notifications**: SNS email alerts sufficient (no PagerDuty/Slack integration required)

### Application

- **Static Health Endpoint**: Service returns JSON status without database dependency
- **Port 8080**: Standard non-privileged port for backend service
- **Python Standard Library**: No external dependencies (Flask, FastAPI, etc.) required
- **Git SHA Tracking**: Commit identifier passed via environment variable for deployment traceability

### Operations

- **Manual SNS Confirmation**: Acceptable for reviewer to confirm email subscription
- **SSM Availability**: AWS Systems Manager Session Manager enabled in AWS account
- **GitHub Repository**: CI/CD pipelines assume repository will be created
- **Reviewer Tools**: AWS CLI and Terraform installed locally

## Prerequisites

### Required Tools

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| AWS CLI | v2.x | AWS resource management |
| Terraform | 1.7.5 | Infrastructure provisioning |
| Ansible | 2.15 | Configuration management |
| Python | 3.9+ | Ansible and application runtime |
| Git | 2.x | Version control |
| jq | 1.6+ | JSON parsing in scripts |

### Required AWS Resources

These resources must be created before deploying infrastructure:

**Backend Resources**:
- S3 bucket: `rewards-terraform-state-<ACCOUNT_ID>` (versioning enabled, encrypted)
- DynamoDB table: `rewards-terraform-locks` (primary key: `LockID`)

**IAM & Authentication**:
- GitHub OIDC provider: `token.actions.githubusercontent.com`
- IAM role: `rewards-github-actions-role` (with trust policy for repository)

**Secrets**:
- SSM Parameter: `/rewards/dev/secrets/APP_SECRET` (SecureString type)

### Required IAM Permissions

The deployment requires permissions for:
- **Networking**: VPC, Subnets, Route Tables, Internet Gateway, NAT Gateway, Security Groups
- **Compute**: EC2, Auto Scaling Groups, Launch Templates
- **Load Balancing**: ALB, Target Groups, Listeners
- **Storage**: S3, DynamoDB
- **Security**: IAM Roles, Policies, Instance Profiles
- **Monitoring**: CloudWatch, SNS
- **Systems Manager**: SSM Parameter Store, Session Manager

## Quick Start

Deploy the complete infrastructure and application in 6 steps:

```bash
# 1. Clone repository and navigate to project
git clone <repository-url>
cd dev-web-tier

# 2. Set environment variables
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-east-1"

# 3. Create backend resources (one-time setup)
# S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket "rewards-terraform-state-${AWS_ACCOUNT_ID}" \
  --region ${AWS_REGION}

aws s3api put-bucket-versioning \
  --bucket "rewards-terraform-state-${AWS_ACCOUNT_ID}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "rewards-terraform-state-${AWS_ACCOUNT_ID}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# DynamoDB table for state locking
aws dynamodb create-table \
  --table-name rewards-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION}

# 4. Initialize and deploy infrastructure
cd terraform
terraform init -backend-config="key=dev/terraform.tfstate"
terraform apply -var-file=environments/dev.tfvars -auto-approve

# 5. Create APP_SECRET (if not exists)
if ! aws ssm get-parameter --name "/rewards/dev/secrets/APP_SECRET" --region ${AWS_REGION} 2>/dev/null; then
  echo "Creating APP_SECRET parameter..."
  aws ssm put-parameter \
    --name "/rewards/dev/secrets/APP_SECRET" \
    --value "dev-secret-$(date +%s)" \
    --type "SecureString" \
    --description "API key for rewards service (dev environment)" \
    --region ${AWS_REGION}
  echo "Secret created successfully"
else
  echo "Secret already exists. Skipping creation."
fi

# 6. Configure instances with Ansible (wait for SSM registration)
cd ../ansible
sleep 60  # Allow SSM agent to register
ansible-playbook -i inventory/aws_ec2.yml playbook.yml

# 7. Get ALB DNS and verify health endpoint
cd ../terraform
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Health endpoint: http://${ALB_DNS}/health"

# Wait for service startup and test
sleep 15
curl http://${ALB_DNS}/health | jq
```

**Expected Output**:
```json
{
  "service": "rewards",
  "status": "ok",
  "commit": "abc123def456",
  "region": "us-east-1"
}
```

## Health Endpoint

**URL**: `http://<ALB-DNS>/health`

**Response Format**:
```json
{
  "service": "rewards",
  "status": "ok",
  "commit": "a1b2c3d4e5f6789",
  "region": "us-east-1"
}
```

**Field Descriptions**:

| Field | Type | Description |
|-------|------|-------------|
| `service` | string | Service identifier (always "rewards") |
| `status` | string | Health status: "ok" or "degraded" |
| `commit` | string | Git SHA for deployment traceability |
| `region` | string | AWS region for multi-region awareness |

**Health Check Configuration**:
- **Protocol**: HTTP
- **Port**: 8080
- **Path**: `/health`
- **Success Code**: 200
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 2 consecutive failures

## CI/CD Pipeline

### GitHub Actions Workflows

**1. Pull Request Validation** ([`.github/workflows/terraform-pr.yml`](.github/workflows/terraform-pr.yml))

Executes on pull requests to `main` branch:

```yaml
Quality Gates:
  - terraform fmt -check        # Code formatting
  - terraform validate          # Syntax validation  
  - terraform plan              # Infrastructure preview
  - ansible-lint                # Playbook quality check
```

**2. Deployment Pipeline** ([`.github/workflows/terraform-apply.yml`](.github/workflows/terraform-apply.yml))

Executes on push to `main` branch:

```yaml
Jobs:
  1. terraform-apply:
     - Configure AWS via OIDC
     - Terraform plan and apply
     - Store commit SHA in SSM
     - Output ALB DNS
  
  2. ansible-deploy:
     - Install Ansible + dependencies
     - Wait for EC2 SSM registration
     - Run configuration playbook
     - Verify health endpoint (5 retries)
```

**Concurrency Control**:
```yaml
concurrency:
  group: rewards-dev-deployment
  cancel-in-progress: false  # Queue deployments, don't cancel
```

### Setup CI/CD

**1. Configure GitHub Secrets**:
```bash
# Set AWS account ID
gh secret set AWS_ACCOUNT_ID --body "123456789012"
```

**2. Create OIDC Provider in AWS**:
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**3. Create IAM Role for GitHub Actions**:

See [`docs/SOLUTION.md`](docs/SOLUTION.md) for complete IAM policy with least privilege permissions.

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": [
          "repo:MantombiM/dev-web-tier:ref:refs/heads/main",
          "repo:MantombiM/dev-web-tier:pull_request"
        ]
      }
    }
  }]
}
```

## Monitoring & Alerts

### CloudWatch Alarms

| Alarm Name | Metric | Threshold | Evaluation | Action |
|------------|--------|-----------|------------|--------|
| `rewards-dev-alb-5xx-errors` | HTTPCode_Target_5XX_Count | >10 errors | 1 period × 5 min | SNS email |
| `rewards-dev-unhealthy-targets` | UnHealthyHostCount | ≥1 target | 2 periods × 1 min | SNS email |
| `rewards-dev-high-cpu` | CPUUtilization | >80% average | 2 periods × 5 min | SNS email |

**SNS Topic**: `rewards-dev-cloudwatch-alarms`  
**Notification Email**: mimimanqele13@gmail.com

**Email Confirmation Required**:
After first deployment, check email for SNS subscription confirmation and click "Confirm subscription" link.

### Viewing Alarms

```bash
# List all alarms
aws cloudwatch describe-alarms \
  --alarm-names rewards-dev-alb-5xx-errors rewards-dev-unhealthy-targets rewards-dev-high-cpu \
  --region us-east-1

# Check alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name rewards-dev-unhealthy-targets \
  --max-records 10 \
  --region us-east-1
```

## Cost Breakdown

### Monthly Cost Estimate (us-east-1)

| Resource | Configuration | Unit Price | Quantity | Monthly Cost |
|----------|--------------|------------|----------|--------------|
| **EC2 Instances** | t4g.nano ARM | $0.0042/hour | 2 instances | $6.05 |
| **Application Load Balancer** | - | $0.0225/hour | 1 ALB | $16.20 |
| **NAT Gateway** | Single AZ | $0.045/hour | 1 gateway | $32.40 |
| **NAT Data Processing** | - | $0.045/GB | 10 GB/month | $0.45 |
| **EBS Storage** | gp3 8GB | $0.08/GB-month | 2 volumes | $1.28 |
| **CloudWatch Alarms** | Standard | $0.10/alarm | 3 alarms | $0.30 |
| **S3 Storage** | Standard | $0.023/GB | 1 GB | $0.50 |
| **DynamoDB** | On-demand | - | Low requests | $0.10 |
| **Cross-AZ Transfer** | ALB→EC2 | $0.01/GB | 5 GB/month | $0.05 |
| **Data Transfer Out** | First 1GB free | $0.09/GB | 1 GB | $0.00 |
| | | | **Total** | **~$57.33/month** |

### Cost Optimization Strategies

**Current Savings**:
- Single NAT Gateway: **-$32/month** vs dual NAT
- ARM instances (t4g.nano): **-$2/month** vs x86 (t3.micro)
- Single-AZ compute: **-$1/month** data transfer savings
- **Total savings**: **~$35/month**

**Production Considerations**:
- Multi-AZ NAT Gateways: **+$32/month**
- Reserved Instances (1-year): **-35% savings** on EC2
- VPC Endpoints (S3, SSM): **-$11/month** vs dual NAT for high traffic

**Cost Monitoring**:
```bash
# View current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=service
```

## Testing the Solution

### Manual Verification Steps

**1. Health Endpoint Validation**:
```bash
# Get ALB DNS from Terraform output
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)

# Test health endpoint
curl http://${ALB_DNS}/health | jq

# Verify response fields
curl -s http://${ALB_DNS}/health | jq -e '.status == "ok"'
```

**2. Target Health Check**:
```bash
# Get target group ARN from Terraform output
TG_ARN=$(cd terraform && terraform output -raw target_group_arn)

# Check target health status
aws elbv2 describe-target-health \
  --target-group-arn ${TG_ARN} \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

**3. SSM Session Manager Access**:
```bash
# List managed instances
aws ssm describe-instance-information \
  --filters "Key=tag:environment,Values=dev" \
  --region us-east-1 \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus,PlatformName]' \
  --output table

# Start interactive session
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:environment,Values=dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ssm start-session --target ${INSTANCE_ID}
```

**4. CloudWatch Alarms Status**:
```bash
# Check all alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix rewards-dev \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

**5. Auto Scaling Group Status**:
```bash
# Get ASG details
ASG_NAME=$(cd terraform && terraform output -raw asg_name)
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${ASG_NAME} \
  --region us-east-1 \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].HealthStatus]'
```

**6. Terraform State Verification**:
```bash
cd terraform

# List all resources in state
terraform state list

# Show specific resource details
terraform state show module.compute.aws_autoscaling_group.main
```

**7. Application Logs**:
```bash
# Connect to instance via SSM
aws ssm start-session --target ${INSTANCE_ID}

# View service status
sudo systemctl status rewards-health

# View service logs
sudo journalctl -u rewards-health -f --no-pager

# Check environment variables (without exposing secrets)
sudo systemctl show rewards-health --property=Environment
```

## Cleanup

### Complete Infrastructure Removal

**Option 1: Terraform Destroy (Recommended)**:
```bash
# Destroy all infrastructure
cd terraform
terraform destroy -var-file=environments/dev.tfvars -auto-approve

# Verify no resources remain
aws ec2 describe-instances \
  --filters "Name=tag:environment,Values=dev" "Name=tag:service,Values=rewards" \
  --region us-east-1
```

**Option 2: Manual Cleanup**:
```bash
# Delete Auto Scaling Group first (forces instance termination)
ASG_NAME=$(cd terraform && terraform output -raw asg_name)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name ${ASG_NAME} \
  --force-delete \
  --region us-east-1

# Wait for instances to terminate
sleep 30

# Then run terraform destroy
cd terraform
terraform destroy -var-file=environments/dev.tfvars -auto-approve
```

### Backend Cleanup (Optional)

**Remove Terraform state and locks**:
```bash
# Empty and delete S3 state bucket
aws s3 rm s3://rewards-terraform-state-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://rewards-terraform-state-${AWS_ACCOUNT_ID} --force

# Delete DynamoDB lock table
aws dynamodb delete-table \
  --table-name rewards-terraform-locks \
  --region us-east-1

# Delete SSM parameters
aws ssm delete-parameter --name "/rewards/dev/secrets/APP_SECRET" --region us-east-1
aws ssm delete-parameter --name "/rewards/dev/app/commit_sha" --region us-east-1 || true
```

**Remove IAM resources**:
```bash
# Delete IAM role (after detaching policies)
aws iam delete-role-policy --role-name rewards-github-actions-role --policy-name TerraformDeployPolicy
aws iam delete-role --role-name rewards-github-actions-role

# Delete OIDC provider
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com
```

## Possible Enhancements

### High Availability

**Multi-AZ Compute Deployment**:
- Deploy ASG instances across us-east-1a and us-east-1b
- Add second NAT Gateway in us-east-1b for zone independence
- Estimated additional cost: **+$32/month**

**Cross-Region Failover**:
- Route53 health checks with failover routing
- Replicate infrastructure in secondary region (us-west-2)
- Multi-region S3 replication for Terraform state

**Database Layer**:
- RDS PostgreSQL Multi-AZ deployment
- Read replicas for improved performance
- Automated backups with point-in-time recovery

### Security Hardening

**TLS/HTTPS Encryption**:
- ACM certificate for custom domain
- Route53 DNS management
- HTTPS-only ALB listener with redirect from HTTP
- Estimated cost: Free (ACM certificates are free)

**Web Application Firewall**:
- AWS WAF integration with ALB
- Managed rule groups for OWASP Top 10
- Rate limiting and geo-blocking
- Estimated cost: **+$5/month** base + request charges

**Enhanced Network Security**:
- VPC Flow Logs for network traffic analysis
- AWS GuardDuty for threat detection
- AWS Security Hub for compliance monitoring
- AWS Config rules for configuration drift detection

**Secrets Rotation**:
- Lambda function for automatic APP_SECRET rotation
- Integration with AWS Secrets Manager
- Notification on rotation completion

### Observability Improvements

**Centralized Logging**:
- CloudWatch Logs with structured JSON logging
- Log groups per service component
- 30-day retention for development, 90-day for production
- CloudWatch Insights queries for log analysis

**Distributed Tracing**:
- AWS X-Ray instrumentation
- Request flow visualization across services
- Performance bottleneck identification
- Latency analysis by endpoint

**Custom Metrics**:
- Application-level metrics via CloudWatch custom metrics
- Request count, latency percentiles (p50, p95, p99)
- Business metrics (successful operations, error rates)

**Dashboard Creation**:
- CloudWatch Dashboard with key metrics
- Real-time monitoring view
- Historical trend analysis
- Anomaly detection alerts

### Application Enhancements

**Blue/Green Deployment**:
- Separate target groups for blue and green environments
- Weighted routing for canary releases
- Automated rollback on health check failures

**API Gateway Integration**:
- REST API with request/response validation
- API key management and rate limiting
- Usage plans and quotas
- Request/response transformation

**CDN via CloudFront**:
- Global content delivery for static assets
- Edge caching for improved latency
- DDoS protection via AWS Shield Standard
- Custom error pages

**Database Integration**:
- RDS PostgreSQL for persistent storage
- Connection pooling via RDS Proxy
- Read replicas for scalability
- Automated backups and maintenance windows

### Operational Improvements

**Automated Patching**:
- AWS Systems Manager Patch Manager
- Maintenance windows for automated updates
- Pre-patch and post-patch validation
- Compliance reporting

**Backup Strategy**:
- AWS Backup for centralized backup management
- Daily snapshots with 30-day retention
- Cross-region backup replication
- Automated restore testing

**Disaster Recovery**:
- Documented DR procedures
- Regular DR drills
- RPO/RTO targets defined
- Failover playbooks

**Cost Optimization**:
- Compute Savings Plans for EC2
- S3 Intelligent-Tiering for logs
- Scheduled scaling for non-business hours
- Regular cost analysis and optimization reviews

## Project Structure

```
dev-web-tier/
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Module orchestration
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── backend.tf               # S3 backend configuration
│   ├── providers.tf             # AWS provider configuration
│   ├── backend.hcl              # Backend initialization config
│   │
│   ├── environments/            # Environment-specific configurations
│   │   └── dev.tfvars          # Development variables
│   │
│   └── modules/                 # Reusable Terraform modules
│       ├── network/            # VPC, subnets, NAT, routing, security groups
│       ├── compute/            # Auto Scaling Group, launch template
│       ├── loadbalancer/       # ALB, target groups, listeners
│       ├── iam/                # Roles, policies, instance profiles
│       └── cloudwatch/         # Alarms, SNS topics
│
├── ansible/                     # Configuration Management
│   ├── ansible.cfg             # Ansible configuration
│   ├── playbook.yml            # Main playbook
│   │
│   ├── inventory/              # Dynamic inventory
│   │   └── aws_ec2.yml        # EC2 dynamic inventory plugin
│   │
│   └── roles/                  # Ansible roles
│       ├── common/            # Base configuration (packages, security)
│       └── health-service/    # Application deployment
│
├── .github/workflows/           # CI/CD Pipelines
│   ├── terraform-pr.yml        # PR validation (plan, lint)
│   └── terraform-apply.yml     # Deployment (apply, configure)
│
├── docs/                        # Documentation
│   └── SOLUTION.md             # Detailed architecture design
│
└── README.md                    # This file
```

## Reference Documentation

- **[`docs/SOLUTION.md`](docs/SOLUTION.md)**: Complete architecture design, technical decisions, trade-offs, and AWS service details

**External Documentation**:
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
