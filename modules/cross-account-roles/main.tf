# modules/cross-account-roles/main.tf

# Role in shared account for workload accounts to access resources
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
            "aws:PrincipalTag/Environment": var.allowed_environments
          }
        }
      }
    ]
  })
  
  tags = merge(var.tags, {
    Name      = "${var.project_name}-shared-resource-access"
    Terraform = "true"
  })
}

# Permissions for shared resources (ECR, S3, etc.)
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
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken"
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
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

# Role in workload accounts to access shared account
resource "aws_iam_role" "shared_account_access" {
  count = var.account_type == "workload" ? 1 : 0
  
  name = "${var.project_name}-${var.env}-shared-account-access"
  
  # Allow GitHub Actions role to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.github_actions_role_arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Policy allowing workload account to assume role in shared account
resource "aws_iam_role_policy" "assume_shared_role" {
  count = var.account_type == "workload" ? 1 : 0
  
  name = "${var.project_name}-${var.env}-assume-shared-role"
  role = aws_iam_role.shared_account_access[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = var.shared_role_arn
      }
    ]
  })
}

# Outputs
output "role_arn" {
  description = "ARN of the created cross-account role"
  value       = var.account_type == "shared" ? aws_iam_role.shared_resource_access[0].arn : aws_iam_role.shared_account_access[0].arn
}