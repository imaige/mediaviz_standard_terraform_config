# modules/cross-account-roles/main.tf

locals {
  normalized_tags = merge(
    var.tags,
    {
      Terraform = "true"
      Project   = var.project_name
    },
    var.account_type == "workload" ? { Environment = var.env } : {}
  )
}

#----------------------------------------------------------
# Shared Account Resources (created when account_type = "shared")
#----------------------------------------------------------
resource "aws_iam_role" "shared_resource_access" {
  count = var.account_type == "shared" ? 1 : 0

  name = "${var.project_name}-shared-resource-access"

  # Allow workload accounts to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.workload_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Environment" : var.allowed_environments
          }
        }
      }
    ]
  })

  tags = local.normalized_tags
}

# ECR access policy
resource "aws_iam_role_policy" "ecr_access" {
  count = var.account_type == "shared" ? 1 : 0

  name = "${var.project_name}-ecr-access-policy"
  role = aws_iam_role.shared_resource_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = var.ecr_repository_arns
      },
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

# S3 access policy
resource "aws_iam_role_policy" "s3_access" {
  count = var.account_type == "shared" ? 1 : 0

  name = "${var.project_name}-s3-access-policy"
  role = aws_iam_role.shared_resource_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

# KMS access policy - for decrypting S3 objects and ECR images
resource "aws_iam_role_policy" "kms_access" {
  count = var.account_type == "shared" ? 1 : 0

  name = "${var.project_name}-kms-access-policy"
  role = aws_iam_role.shared_resource_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arns
      }
    ]
  })
}

# CI/CD access policy - separate policy with additional permissions for CI/CD roles
# Replace this in your modules/cross-account-roles/main.tf
resource "aws_iam_role_policy" "cicd_access" {
  count = var.account_type == "shared" && length(var.cicd_principal_arns) > 0 ? 1 : 0

  name = "${var.project_name}-cicd-access-policy"
  role = aws_iam_role.shared_resource_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        # Remove the Principal section - it's not allowed in role policies
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "s3:PutObject",
          "s3:DeleteObject",
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ]
        Resource = concat(var.ecr_repository_arns, var.s3_bucket_arns, var.kms_key_arns)
      }
    ]
  })
}

#----------------------------------------------------------
# Workload Account Resources (created when account_type = "workload")
#----------------------------------------------------------

# Role for accessing shared account resources
resource "aws_iam_role" "shared_account_access" {
  count = var.account_type == "workload" ? 1 : 0

  name = "${var.project_name}-${var.env}-shared-account-access"

  # Allow specified roles (GitHub Actions, etc.) to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Allow GitHub Actions role
      var.github_actions_role_arn != "" ? [
        {
          Effect = "Allow"
          Principal = {
            AWS = var.github_actions_role_arn
          }
          Action = "sts:AssumeRole"
        }
      ] : [],
      # Allow additional principals if specified
      length(var.additional_principal_arns) > 0 ? [
        {
          Effect = "Allow"
          Principal = {
            AWS = var.additional_principal_arns
          }
          Action = "sts:AssumeRole"
        }
      ] : []
    )
  })

  tags = local.normalized_tags
}

# Policy allowing workload account role to assume role in shared account
resource "aws_iam_role_policy" "assume_shared_role" {
  count = var.account_type == "workload" && var.shared_role_arn != "" ? 1 : 0

  name = "${var.project_name}-${var.env}-assume-shared-role"
  role = aws_iam_role.shared_account_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.shared_role_arn
      }
    ]
  })
}

# Direct ECR access permissions for workload account's role (optional)
resource "aws_iam_role_policy" "workload_ecr_access" {
  count = var.account_type == "workload" && length(var.ecr_repository_arns) > 0 ? 1 : 0

  name = "${var.project_name}-${var.env}-ecr-direct-access"
  role = aws_iam_role.shared_account_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = var.ecr_repository_arns
      },
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

# Direct S3 access permissions for workload account's role (optional)
resource "aws_iam_role_policy" "workload_s3_access" {
  count = var.account_type == "workload" && length(var.s3_bucket_arns) > 0 ? 1 : 0

  name = "${var.project_name}-${var.env}-s3-direct-access"
  role = aws_iam_role.shared_account_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

#----------------------------------------------------------
# Outputs
#----------------------------------------------------------
output "role_arn" {
  description = "ARN of the created cross-account role"
  value       = var.account_type == "shared" ? aws_iam_role.shared_resource_access[0].arn : aws_iam_role.shared_account_access[0].arn
}

output "role_name" {
  description = "Name of the created cross-account role"
  value       = var.account_type == "shared" ? aws_iam_role.shared_resource_access[0].name : aws_iam_role.shared_account_access[0].name
}