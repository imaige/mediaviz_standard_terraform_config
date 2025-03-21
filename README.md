# MediaViz Infrastructure Documentation

Infrastructure as Code (IaC) setup for MediaViz platform using Terraform and AWS.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.10.3
- [AWS CLI v2](https://aws.amazon.com/cli/) for SSO authentication
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for Kubernetes cluster management

## AWS Authentication

### SSO Setup

1. Configure AWS SSO:
```bash
aws configure sso
# Follow the prompts:
# SSO session name: mediaviz
# SSO start URL: https://d-9a677e96f7.awsapps.com/start
# SSO Region: us-east-2
# Choose account and role when prompted
```

2. List available SSO profiles:
```bash
aws configure list-profiles
```

3. Use SSO profile:
```bash
export AWS_PROFILE=mediaviz-{ENVIRONMENT}
# Verify authentication
aws sts get-caller-identity
```

### EKS Authentication via SSO

1. Add cluster to your kubeconfig with SSO profile:
```bash
aws eks update-kubeconfig --region us-east-2 --name mediaviz-{ENVIRONMENT}-cluster \
    --profile mediaviz-{ENVIRONMENT}
```

2. Update kubeconfig for SSO authentication:
```bash
kubectl config set-credential mediaviz-{ENVIRONMENT}-cluster \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=aws \
    --exec-arg=eks \
    --exec-arg=get-token \
    --exec-arg=--cluster-name \
    --exec-arg=mediaviz-{ENVIRONMENT}-cluster \
    --exec-arg=--profile \
    --exec-arg=mediaviz-{ENVIRONMENT}
```

## Project Structure

```
├── environments/
│   ├── dev/
│   ├── qa/
│   ├── prod/
│   └── shared/
├── modules/
│   ├── api_gateway/
│   ├── lambda/
│   └── ...
└── README.md
```

## Getting Started

### Initial Setup

1. Initialize Terraform with backend configuration:
```bash
cd environments/{ENVIRONMENT}
terraform init -backend-config=backend-config.hcl
```

2. Validate your Terraform configuration:
```bash
terraform validate -var-file terraform.tfvars
```

3. Create execution plan:
```bash
terraform plan -var-file terraform.tfvars -out plan.out
```

4. Apply the changes:
```bash
terraform apply -input=false plan.out
```

## Security

### Security Scanning

We use multiple tools to ensure infrastructure security:

1. [Checkov](https://www.checkov.io/5.Policy%20Index/terraform.html) for security and compliance scanning
2. IDE extensions:
   - VSCode: HashiCorp Terraform
   - JetBrains IDEs: HashiCorp Terraform / HCL language support

### Best Practices

1. Always use `plan.out` file when applying changes
2. Review security scan results before applying changes
3. Use branch protection and require PR reviews
4. Maintain separate environments (dev/qa/prod)
5. Follow least privilege principle for IAM roles

## CI/CD Pipeline

Our GitHub Actions workflow:
1. Runs Terraform format check
2. Validates configuration
3. Creates plan on PR
4. Applies changes only after merge to main

# Database Access

## Aurora Serverless v2

The Aurora PostgreSQL database is deployed in private subnets and is not publicly accessible. Access is managed through a bastion host.

## Accessing the Database

1. Download the bastion host SSH key:
```bash
# Retrieve SSH key from Secrets Manager
aws secretsmanager get-secret-value \
    --secret-id mediaviz-{ENVIRONMENT}-bastion-key \
    --query 'SecretString' \
    --output text > mediaviz-{ENVIRONMENT}-bastion.pem

# Set correct permissions
chmod 400 mediaviz-{ENVIRONMENT}-bastion.pem
```

2. Create SSH tunnel through bastion host (get the correct values for your environment):
```bash
ssh -i mediaviz-{ENVIRONMENT}-bastion.pem -L 5433:{AURORA_ENDPOINT}:5432 ec2-user@{BASTION_IP}
```

3. Connect to the database through the tunnel:
```bash
psql -h localhost -p 5433 -U postgres -d imaige
```

4. Database credentials can be retrieved from Secrets Manager:
```bash
# Get Aurora credentials
aws secretsmanager get-secret-value \
    --secret-id mediaviz-{ENVIRONMENT}-aurora-credentials-pg \
    --query 'SecretString' \
    --output text | jq '.'
```

## Security Notes

- The database is not publicly accessible
- All access is controlled via the bastion host
- SSH key and database credentials are stored in AWS Secrets Manager
- Always use SSH tunneling for database connections
- Never expose database credentials in code or version control

## Common Database Operations

### Checking Available Tables
```bash
# List all tables in the public schema
psql -h localhost -p 5433 -U postgres -d imaige -c "\dt public.*;"

# Get detailed table information
psql -h localhost -p 5433 -U postgres -d imaige -c "\d+"
```

### Database Migration
When migrating data from another database:
```bash
# Example using pg_dump through SSH tunnel
PGPASSWORD='source_password' pg_dump \
    -h source_host \
    -p 5432 \
    -U postgres \
    -d source_db \
    --exclude-table-data 'pattern_to_exclude' \
    --no-owner \
    --no-acl \
    | PGPASSWORD='target_password' psql \
    -h localhost \
    -p 5433 \
    -U postgres \
    -d imaige
```

## Troubleshooting

1. If port 5433 is already in use:
   - Try a different local port (e.g., 5434)
   - Or check and kill existing PostgreSQL processes

2. If SSH connection fails:
   - Verify bastion host IP is current
   - Check security group allows your IP
   - Ensure correct permissions on .pem file (chmod 400)

3. If database connection fails:
   - Verify you're using the correct credentials
   - Ensure SSH tunnel is active
   - Check if the database is running

## Environment-Specific Information

### Getting Environment-Specific Values

To get the correct values for your environment, run:

```bash
# For bastion host IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=mediaviz-{ENVIRONMENT}-bastion" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --profile mediaviz-{ENVIRONMENT} \
    --output text

# For Aurora endpoint
aws rds describe-db-clusters \
    --db-cluster-identifier mediaviz-{ENVIRONMENT}-aurora \
    --query "DBClusters[0].Endpoint" \
    --profile mediaviz-{ENVIRONMENT} \
    --output text
```

## Common Issues

1. **SSO Session Expired**: Run `aws sso login --profile mediaviz-{ENVIRONMENT}` to refresh
2. **State Lock**: If state is locked, check for running operations or manually unlock if needed
3. **EKS Access**: Ensure your SSO role has appropriate EKS permissions
4. **Backend Issues**: Verify S3 bucket and DynamoDB table permissions

## Contributing

1. Create a new branch from `main`
2. Make your changes
3. Run security scans
4. Create PR with detailed description
5. Wait for review and CI checks to pass

## Infrastructure Components

- VPC with public/private subnets
- EKS cluster with managed node groups
- API Gateway for serverless endpoints
- Lambda functions for image processing
- S3 buckets for storage
- EventBridge for event routing
- SQS queues for async processing
