# modules/github-oidc/main.tf

# Create the OIDC provider for GitHub in each account
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC thumbprint
}

# IAM role for GitHub Actions with trust relationship
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.env}-github-actions-role"

  # Trust policy for GitHub OIDC provider
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Using a wildcard to allow all repositories in the organization
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/*:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Create cross-account policies
resource "aws_iam_role_policy" "cross_account_access" {
  count = length(var.cross_account_roles) > 0 ? 1 : 0
  name  = "${var.project_name}-${var.env}-cross-account-access"
  role  = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.cross_account_roles
      }
    ]
  })
}

# Base permissions for GitHub Actions
resource "aws_iam_role_policy" "github_actions_base" {
  name = "${var.project_name}-${var.env}-github-actions-base"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Conditional policy for specific account types
resource "aws_iam_role_policy" "account_specific" {
  name = "${var.project_name}-${var.env}-account-specific"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Shared services account specific permissions
      var.account_type == "shared" ? [
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "arn:aws:s3:::${var.project_name}-${var.env}-helm-charts",
            "arn:aws:s3:::${var.project_name}-${var.env}-helm-charts/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:DescribeRepositories",
            "ecr:ListImages"
          ]
          Resource = [
            "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project_name}-shared-*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ]
          Resource = ["*"]
        }
      ] : [],

      # Workload account permissions for EKS and Lambda
      var.account_type == "workload" ? [
        {
          Effect = "Allow"
          Action = [
            "eks:DescribeCluster",
            "eks:ListClusters",
            "lambda:UpdateFunctionCode",
            "lambda:GetFunction",
            "eks:AccessKubernetesApi"
          ]
          Resource = "*"
        }
      ] : [],

      # Workload account permissions for ECR
      var.account_type == "workload" && length(var.shared_ecr_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchCheckLayerAvailability"
          ]
          Resource = var.shared_ecr_arns
        }
      ] : [],

      # Workload account permissions for S3
      var.account_type == "workload" && length(var.shared_s3_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = var.shared_s3_arns
        }
      ] : [],

      # Workload account permissions for KMS
      var.account_type == "workload" && length(var.kms_key_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          Resource = ["*"]
        }
      ] : []
    )
  })
}

# Enhanced permissions for CI/CD workflows
resource "aws_iam_role_policy" "cicd_workflow" {
  count = var.enable_cicd_permissions ? 1 : 0
  name  = "${var.project_name}-${var.env}-github-actions-cicd"
  role  = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.account_type == "shared" ? ["arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project_name}-shared-*"] : var.shared_ecr_arns
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:UpdateFunctionConfiguration"
        ]
        Resource = var.account_type == "workload" ? ["arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.project_name}-${var.env}-*"] : []
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = var.account_type == "workload" ? ["arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${var.cluster_name}"] : []
      }
    ]
  })
}

# Get current account ID
data "aws_caller_identity" "current" {}

# Outputs to use in GitHub Actions workflows
output "role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
