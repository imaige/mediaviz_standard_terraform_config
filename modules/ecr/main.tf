# modules/ecr/main.tf

locals {
  repositories = [
    "l-blur-model",
    "l-colors-model",
    "l-image-comparison-model", 
    "l-facial-recognition-model",
    "l-feature-extraction-model"
  ]
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

  tags = merge(var.tags, {
    Environment = var.env
    Name        = each.value
    Terraform   = "true"
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

# IAM policy document for repository
data "aws_iam_policy_document" "lambda_repos" {
  for_each = toset(local.repositories)

  version = "2012-10-17"

  statement {
    sid    = "AllowLambdaAccess"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
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
    for repo in local.repositories :
    repo => aws_ecr_repository.lambda_repos[repo].repository_url
  }
}

output "repository_arns" {
  description = "ARNs of the created ECR repositories"
  value = {
    for repo in local.repositories :
    repo => aws_ecr_repository.lambda_repos[repo].arn
  }
}