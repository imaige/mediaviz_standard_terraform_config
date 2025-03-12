# modules/github-oidc/main.tf

# Create the OIDC provider for GitHub in each account
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]  # GitHub OIDC thumbprint
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
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
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
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
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
            "ecr:*"
          ]
          Resource = "*"  # Scope this down to specific resources
        }
      ] : [],
      
      # Workload account specific permissions
      var.account_type == "workload" ? [
        {
          Effect = "Allow"
          Action = [
            "eks:DescribeCluster",
            "eks:ListClusters",
            "lambda:UpdateFunctionCode",
            "lambda:GetFunction"
          ]
          Resource = "*"  # Scope this down to specific resources
        }
      ] : []
    )
  })
}

# Outputs to use in GitHub Actions workflows
output "role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}