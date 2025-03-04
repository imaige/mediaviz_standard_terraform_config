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
        # Add the new evidence model here
    "evidence-model" = {
      short_name      = "evidence"
      service_account = "eks-processor-evidence-model"
      needs_sqs       = false  # Set to true if it needs SQS, otherwise false
      needs_helm      = false  # Set to true if it needs Helm deployment
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

  tags = {
    Name        = "${var.project_name}-${var.env}-eks-${each.key}"
    Environment = var.env
    Terraform   = "true"
  }
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
      sqs_queue_url    = var.sqs_queues[each.key]
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

  tags = {
    Name        = "${var.project_name}-${var.env}-eks-${each.key}-role"
    Environment = var.env
    Terraform   = "true"
  }
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
      each.value.needs_sqs ? [
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
      # Common permissions for all models
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::*",
            "arn:aws:s3:::*/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "rds-data:*"
          ]
          Resource = var.aurora_cluster_arn
        },
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:*",
            "kms:*"
          ]
          Resource = ["*"]
        }
      ]
    )
  })
}

# Get current account ID
data "aws_caller_identity" "current" {}