# Neal Street Technologies - Rewards Web Tier

Senior Cloud Engineer Technical Assessment

## Overview
Production-shaped AWS infrastructure for the "rewards" web tier using Terraform, Ansible, and GitHub Actions.

## Prerequisites
- AWS Account with appropriate permissions
- Terraform >= 1.7.5
- Ansible >= 2.15
- Python 3.9+
- GitHub repository with OIDC configured

## Quick Start
(Detailed instructions to be added)

## Architecture
See [SOLUTION.md](./SOLUTION.md) for complete architecture documentation.

## Health Endpoint
- **URL**: `http://<alb-dns-name>/health`
- **Response**: `{"service":"rewards","status":"ok","commit":"<git-sha>","region":"<aws-region>"}`

## Cleanup
(Instructions to be added)
