# MediaViz Standard Terraform Configuration

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
export AWS_PROFILE=mediaviz
# Verify authentication
aws sts get-caller-identity
```

### EKS Authentication via SSO

1. Add cluster to your kubeconfig with SSO profile:
```bash
aws eks update-kubeconfig --region us-east-2 --name mediaviz-dev-cluster \
    --profile mediaviz
```

2. Update kubeconfig for SSO authentication:
```bash
kubectl config set-credential mediaviz-dev-cluster \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=aws \
    --exec-arg=eks \
    --exec-arg=get-token \
    --exec-arg=--cluster-name \
    --exec-arg=mediaviz-dev-cluster \
    --exec-arg=--profile \
    --exec-arg=mediaviz
```

## Project Structure

```
├── environments/
│   ├── dev/
│   │   ├── backend-config.hcl
│   │   └── terraform.tfvars
│   └── prod/
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
terraform init -backend-config=dev/backend-config.hcl
```

2. Validate your Terraform configuration:
```bash
terraform validate -var-file dev/terraform.tfvars
```

3. Create execution plan:
```bash
terraform plan -var-file dev/terraform.tfvars -out plan.out
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
4. Maintain separate environments (dev/prod)
5. Follow least privilege principle for IAM roles

## CI/CD Pipeline

Our GitHub Actions workflow:
1. Runs Terraform format check
2. Validates configuration
3. Creates plan on PR
4. Applies changes only after merge to main

## Common Issues

1. **SSO Session Expired**: Run `aws sso login --profile mediaviz` to refresh
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

## License

[Add your license information here]