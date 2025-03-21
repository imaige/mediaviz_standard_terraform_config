locals {
  models = {
    "feature-extraction-model" = {
      short_name = "feature-extraction"
      needs_sqs  = true
    }
    "image-classification-model" = {
      short_name = "image-classification"
      needs_sqs  = true
    }
    "external-api" = {
      short_name = "external-api"
      needs_sqs  = false
    }
    "evidence-model" = {
      short_name = "evidence"
      needs_sqs  = false
    }
  }
  
  # Filtered map for models that need SQS
  sqs_models = {
    for k, v in local.models : k => v if v.needs_sqs
  }
  
  # Normalize tags for consistency
  normalized_tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
    Project     = var.project_name
  })
}

# IAM roles for all models
resource "aws_iam_role" "model_role" {
  for_each = local.models

  name = "${var.project_name}-${var.env}-eks-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Service account name to be created by Helm in CI/CD
            "${replace(var.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:eks-${each.value.short_name}"
          }
        }
      }
    ]
  })

  tags = local.normalized_tags
}

# IAM policies for all models
resource "aws_iam_role_policy" "model_policies" {
  for_each = local.models

  name = "${var.project_name}-${var.env}-eks-${each.key}-policy"
  role = aws_iam_role.model_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Cross-account ECR access
      [
        {
          Effect = "Allow"
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability"
          ]
          Resource = [
            "arn:aws:ecr:${var.aws_region}:${var.shared_account_id}:repository/${var.project_name}-shared-eks-*"
          ]
        },
        {
          Effect = "Allow"
          Action = ["ecr:GetAuthorizationToken"]
          Resource = ["*"]
        }
      ],
      # SQS permissions - only for models that need it
      each.value.needs_sqs && contains(keys(var.sqs_queues), each.key) ? [
        {
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:SendMessage",
            "sqs:ChangeMessageVisibility"
          ]
          Resource = [
            "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${split("/", lookup(var.sqs_queues, each.key, ""))[4]}"
          ]
        }
      ] : [],
      # Other AWS service permissions
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = concat(
            var.s3_bucket_arns,
            [for bucket in var.s3_bucket_arns : "${bucket}/*"]
          )
        },
        {
          Effect = "Allow"
          Action = [
            "rds-data:ExecuteStatement",
            "rds-data:BatchExecuteStatement",
            "rds-data:BeginTransaction",
            "rds-data:CommitTransaction",
            "rds-data:RollbackTransaction"
          ]
          Resource = var.aurora_cluster_arn
        },
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ]
          Resource = [
            var.aurora_secret_arn,
            "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.env}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:GenerateDataKey*"
          ]
          Resource = var.kms_key_arn
        }
      ]
    )
  })
}

# Get current account ID
data "aws_caller_identity" "current" {}