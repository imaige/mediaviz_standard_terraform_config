# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# MediaViz Infrastructure Configuration

This is a multi-account AWS infrastructure setup for the MediaViz platform using Terraform. The architecture includes both container-based (EKS) and serverless (Lambda) components for AI/ML image processing workloads.

## Commands

### Standard Terraform Operations
- **Init**: `terraform init -backend-config=backend-config.hcl`
- **Validate**: `terraform validate -var-file terraform.tfvars`
- **Plan**: `terraform plan -var-file terraform.tfvars -out plan.out`
- **Apply**: `terraform apply -input=false plan.out`
- **Format**: `terraform fmt -check -recursive`
- **Security Scan**: `checkov -d . --framework terraform`

### AWS Authentication (SSO)
```bash
aws configure sso
export AWS_PROFILE=mediaviz-{ENVIRONMENT}
aws sts get-caller-identity
```

### Database Access via Bastion
```bash
# Get SSH key from Secrets Manager
aws secretsmanager get-secret-value --secret-id mediaviz-{ENVIRONMENT}-bastion-key --query 'SecretString' --output text > bastion.pem
chmod 400 bastion.pem

# Create SSH tunnel
ssh -i bastion.pem -L 5433:{AURORA_ENDPOINT}:5432 ec2-user@{BASTION_IP}

# Connect to database
psql -h localhost -p 5433 -U postgres -d imaige
```

### EKS Authentication
```bash
aws eks update-kubeconfig --region us-east-2 --name mediaviz-{ENVIRONMENT}-cluster --profile mediaviz-{ENVIRONMENT}
```

## Architecture Overview

### Multi-Account Structure
- **Shared Account**: ECR repositories, S3 storage, Helm charts, cross-account IAM roles
- **Workload Accounts**: Environment-specific infrastructure (dev/qa/prod)

### Core Infrastructure Components
1. **VPC & Networking**: Multi-AZ setup with public/private subnets
2. **EKS Cluster**: Managed Kubernetes with both standard and GPU node groups
3. **Aurora Serverless v2**: PostgreSQL database in private subnets
4. **API Gateway**: REST API endpoints with WAF protection
5. **Lambda Functions**: Serverless image processing (upload & processors)
6. **EventBridge**: Event routing between components
7. **SQS**: Message queuing with DLQ for failed processing
8. **S3**: Object storage with cross-replication
9. **Bastion Host**: Secure database access

### Processing Pipeline
- **Image Upload**: API Gateway → Lambda Upload → S3 → EventBridge
- **AI Processing**: EventBridge → SQS → Lambda/EKS Processors → Aurora
- **Model Types**: Blur, colors, facial recognition (Lambda), feature extraction, classification (EKS/GPU)

## Environment Structure

### Directory Layout
```
environments/
├── shared/     # Shared account resources (ECR, S3, cross-account roles)
├── dev/        # Development environment
├── qa/         # QA environment
└── prod/       # Production environment

modules/
├── networking/     # VPC, subnets, security groups
├── eks/           # EKS cluster with GPU support
├── aurora/        # PostgreSQL database
├── lambda_*/      # Serverless functions
├── api_gateway/   # REST API
├── eventbridge/   # Event routing
├── sqs/          # Message queues
├── s3/           # Object storage
├── security/     # KMS, IAM, WAF
└── bastion/      # Database access host
```

### Cross-Account Dependencies
- Lambda processors use shared ECR repositories: `${shared_account_id}.dkr.ecr.us-east-2.amazonaws.com/${project_name}-shared`
- Workload accounts assume cross-account roles in shared account for resource access
- GitHub OIDC providers enable CI/CD access across accounts

## Code Style Guidelines

### Terraform Conventions
- **Formatting**: 2-space indentation, aligned parameter values, empty lines between logical blocks
- **Naming**: Snake_case for variables; hyphenated resource names `${var.project_name}-${var.env}-[resource-purpose]`
- **Variables**: Include description, type, default value; mark sensitive variables appropriately
- **Module Structure**: Separate `main.tf`, `variables.tf`, `outputs.tf` per module
- **Resource Naming**: Append function/type suffix (e.g., `-role`, `-policy`, `-sg`)
- **Tags**: Apply standard tags using `merge(var.tags, {...})` pattern

### Security Requirements
- Follow least privilege principle for all IAM roles/policies
- Use KMS encryption for all data at rest and in transit
- Implement specific ingress/egress rules (no 0.0.0.0/0 except where necessary)
- Store sensitive data in AWS Secrets Manager, never in code
- Enable DLQs for all processing queues to handle failures

### Error Handling
- Use `depends_on` for explicit resource dependencies
- Implement `lifecycle` blocks for critical resources
- Configure Dead Letter Queues for SQS-based processing
- Set appropriate timeouts for Lambda functions (upload: 30s, processors: 300s)

## Development Workflow

### Working with Environments
1. Navigate to specific environment: `cd environments/{dev|qa|prod}`
2. Ensure correct AWS profile is set
3. Always run validation before planning
4. Review security scans before applying
5. Use plan files for consistent deployments

### Module Development
- Test modules in dev environment first
- Update shared resources carefully (affects all environments)
- Coordinate EKS cluster changes with application deployments
- Monitor Aurora capacity during database schema changes

### Required Provider Versions
- AWS: ~> 5.0
- Kubernetes: ~> 2.20
- Helm: ~> 2.17.0
- Time: ~> 0.9

### Database Operations
- Aurora is not publicly accessible - always use bastion host
- Database name: `imaige`
- Credentials stored in Secrets Manager: `mediaviz-{env}-aurora-credentials-pg`
- SSH keys stored in Secrets Manager: `mediaviz-{env}-bastion-key`

### CI/CD Pipeline Commands
- **GitHub Actions**: Automatically runs on PRs and main branch pushes
- **Manual Plan**: `terraform plan -no-color` (used in CI)
- **Manual Apply**: `terraform apply -auto-approve` (used in CI)
- **Terraform Version**: 1.10.3 (specified in CI pipeline)

### ArgoCD Management
```bash
# Port forward to ArgoCD server (after EKS authentication)
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Access ArgoCD CLI
argocd login localhost:8080

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Backend Configuration Notes
- Backend configuration is embedded in `terraform.tf` files (not separate `.hcl` files)
- S3 bucket pattern: `mediaviz-terraform-backend-config-{environment}`
- DynamoDB table pattern: `mediaviz-terraform-backend-config-{environment}`
- All backends use encryption and are in `us-east-2` region

### Working Directory Patterns
- Always work from environment-specific directories: `cd environments/{env}`
- CI/CD currently targets `dev` environment by default
- Each environment has its own `terraform.tfvars` file
- State files are environment-isolated in separate S3 buckets

## Time-of-Day Scaling Implementation Plan

### Current Scaling Configuration
- **QA Environment**: 3 evidence pods, 5 image classification pods, 1 feature extraction pod
- **Dev Environment**: 1 evidence pod, 2 image classification pods (for testing), 1 feature extraction pod

### Target Scaling Schedule (Pacific Time)
- **Business Hours (5am-7pm PT)**: Full capacity as configured above
- **Off Hours (7pm-5am PT)**: Scale down all pods to 1 replica each

### Implementation Options

#### Option 1: Kubernetes CronJobs with kubectl
```bash
# Scale up at 5am PT (12pm UTC)
kubectl scale deployment eks-evidence-model --replicas=3
kubectl scale deployment eks-image-classification-model --replicas=5

# Scale down at 7pm PT (2am UTC next day)
kubectl scale deployment eks-evidence-model --replicas=1
kubectl scale deployment eks-image-classification-model --replicas=1
```

#### Option 2: Terraform + External Scheduler
- Use external scheduler (GitHub Actions, AWS Lambda with EventBridge)
- Update Terraform variables based on time
- Apply changes automatically

#### Option 3: Kubernetes HPA with Custom Metrics
- Implement time-based custom metrics
- Use HorizontalPodAutoscaler with time-aware scaling

### Recommended Approach
Use Kubernetes CronJobs within the cluster for simplicity and reliability:
1. Create CronJobs that run kubectl scale commands
2. Set timezone to America/Los_Angeles for Pacific Time
3. Configure proper RBAC permissions for scaling operations