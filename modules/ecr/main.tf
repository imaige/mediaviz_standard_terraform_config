# modules/ecr/main.tf

locals {
  # Default repositories if none are specified via variable
  default_repositories = [
    "l-blur-model",
    "l-colors-model",
    "l-image-comparison-model", 
    "l-facial-recognition-model",
    "eks-feature-extraction-model",
    "eks-image-comparison-model",
    "eks-mediaviz-external-api",
    "eks-evidence-model",
    "eks-similarity-model",
    "eks-similarity-set-sorting-service",
    "eks-image-classification-model",
    "eks-external-api",
    "eks-personhood-model",
  ]
  
  # Use provided repositories if specified, otherwise use defaults
  repositories = length(var.ecr_repositories) > 0 ? var.ecr_repositories : local.default_repositories
  
  # Normalize tags
  normalized_tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

resource "aws_ecr_repository" "lambda_repos" {
  for_each = toset(local.repositories)

  name = "${var.project_name}-${var.env}-${each.value}"
  
  image_tag_mutability = "MUTABLE"  # Allows overwriting of tags like 'latest'
  
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key        = var.kms_key_arn
  }

  tags = merge(local.normalized_tags, {
    Name = each.value
    Type = startswith(each.value, "l-") ? "lambda" : "eks"
  })
}

# Lifecycle policy for each repository
resource "aws_ecr_lifecycle_policy" "lambda_repos" {
  for_each = toset(local.repositories)

  repository = aws_ecr_repository.lambda_repos[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Authorization token policy for cross-account access
resource "aws_iam_policy" "ecr_auth_token" {
  count = length(var.cross_account_arns) > 0 ? 1 : 0
  
  name        = "${var.project_name}-${var.env}-ecr-auth-token"
  description = "Policy allowing ECR GetAuthorizationToken for cross-account access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
  
  tags = local.normalized_tags
}

# IAM policy document for repository
data "aws_iam_policy_document" "lambda_repos" {
  for_each = toset(local.repositories)

  version = "2012-10-17"

  statement {
    sid    = "AllowServiceAccess"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = startswith(each.value, "l-") ? ["lambda.amazonaws.com"] : ["eks.amazonaws.com"]
    }

    principals {
      type = "AWS"
      identifiers = concat(
        ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
        var.cross_account_arns
      )
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
  }
}

# Add data source for current account ID
data "aws_caller_identity" "current" {}

resource "aws_ecr_repository_policy" "lambda_repos" {
  for_each = toset(local.repositories)

  repository = aws_ecr_repository.lambda_repos[each.value].name
  policy     = data.aws_iam_policy_document.lambda_repos[each.value].json
}

# Outputs
output "repository_urls" {
  description = "URLs of the created ECR repositories"
  value = {
    for k in local.repositories : k => aws_ecr_repository.lambda_repos[k].repository_url
  }
}

output "repository_arns" {
  description = "ARNs of the created ECR repositories"
  value = {
    for k in local.repositories : k => aws_ecr_repository.lambda_repos[k].arn
  }
}

output "auth_token_policy_arn" {
  description = "ARN of the ECR GetAuthorizationToken policy"
  value       = length(var.cross_account_arns) > 0 ? aws_iam_policy.ecr_auth_token[0].arn : null
}