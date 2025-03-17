locals {
  models = {
    "feature-extraction-model" = {
      short_name      = "feature-extraction"
      service_account = "eks-processor-feature-extraction-model"
      needs_sqs       = true
      needs_helm      = true
    }
    "image-classification-model" = {
      short_name      = "image-classification"
      service_account = "eks-processor-image-classification-model"
      needs_sqs       = true
      needs_helm      = true
    }
    "external-api" = {
      short_name      = "external-api"
      service_account = "eks-processor-external-api"
      needs_sqs       = false
      needs_helm      = false
    }
    "evidence-model" = {
      short_name      = "evidence"
      service_account = "eks-processor-evidence-model"
      needs_sqs       = false
      needs_helm      = false
    }
  }
  
  # Filtered map for models that need Helm deployments
  helm_models = {
    for k, v in local.models : k => v if v.needs_helm
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

# ECR repositories for all models
resource "aws_ecr_repository" "model_repos" {
  for_each = local.models

  name                 = "${var.project_name}-${var.env}-eks-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(local.normalized_tags, {
    Name = "${var.project_name}-${var.env}-eks-${each.key}"
  })
}

# ECR repository policy for cross-account access (if needed)
resource "aws_ecr_repository_policy" "cross_account_policy" {
  for_each = length(var.cross_account_arns) > 0 ? aws_ecr_repository.model_repos : {}

  repository = each.value.name
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = var.cross_account_arns
        },
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# Helm releases only for models that need it
resource "helm_release" "model_deployments" {
  for_each = local.helm_models

  name      = "eks-${each.value.short_name}"
  namespace = var.namespace
  chart     = "${path.module}/chart"

  create_namespace = true
  wait             = true
  atomic           = true

  values = [
    templatefile("${path.module}/chart/values.yaml", {
      image_repository = aws_ecr_repository.model_repos[each.key].repository_url
      image_tag        = "latest"
      role_arn         = aws_iam_role.model_role[each.key].arn
      sqs_queue_url    = lookup(var.sqs_queues, each.key, "")
      aws_region       = var.aws_region
      environment      = var.env
      model_name       = each.key
      short_name       = each.value.short_name
      db_cluster_arn   = var.aurora_cluster_arn
      db_secret_arn    = var.aurora_secret_arn
      db_name          = var.aurora_database_name
    })
  ]

  depends_on = [
    aws_ecr_repository.model_repos,
    aws_iam_role.model_role
  ]
}

# Service accounts for all models
resource "kubernetes_service_account" "model_service_accounts" {
  for_each = local.models

  metadata {
    name      = "eks-processor-${each.value.short_name}-model"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.model_role[each.key].arn
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = each.key
    }
  }
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
            "${replace(var.oidc_provider, "https://", "")}:sub" : "system:serviceaccount:${var.namespace}:eks-processor-${each.value.short_name}-model"
          }
        }
      }
    ]
  })

  tags = merge(local.normalized_tags, {
    Name = "${var.project_name}-${var.env}-eks-${each.key}-role"
  })
}

# IAM policies for all models, with conditional SQS permissions
resource "aws_iam_role_policy" "model_policies" {
  for_each = local.models

  name = "${var.project_name}-${var.env}-eks-${each.key}-policy"
  role = aws_iam_role.model_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
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
            "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${split("/", var.sqs_queues[each.key])[4]}"
          ]
        }
      ] : [],
      # S3 permissions with more specific resources
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = concat(
            [for bucket in var.s3_bucket_arns : bucket],
            [for bucket in var.s3_bucket_arns : "${bucket}/*"]
          )
        },
        # Aurora RDS Data API permissions
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
        # Secrets Manager permissions
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
        # KMS permissions
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