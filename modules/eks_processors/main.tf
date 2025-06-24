locals {
  models = {
    "feature-extraction-model" = {
      short_name = "feature-extraction-model"
      needs_sqs  = true
      needs_helm = true
    }
    "image-classification-model" = {
      short_name = "image-classification-model"
      needs_sqs  = true
      needs_helm = true
    }
    "external-api" = {
      short_name = "external-api-model"
      needs_helm = true
      needs_sqs  = true
    }
    "evidence-model" = {
      short_name      = "evidence-model"
      needs_helm      = true
      needs_sqs       = true
      dedicated_nodes = true
      node_selector = {
        "node-type"     = "high-power-gpu"
        "workload-type" = "evidence-model"
      }
      tolerations = [
        {
          key      = "evidence-model"
          value    = "dedicated"
          effect   = "NoSchedule"
          operator = "Equal"
        }
      ]
    }
    "similarity-model" = {
      short_name = "similarity-model"
      needs_helm = true
      needs_sqs  = true
    }
    "similarity-set-sorting-service" = {
      short_name = "similarity-set-sorting-service"
      needs_helm = true
      needs_sqs  = true
    }
    "personhood-model" = {
      short_name = "personhood-model"
      needs_helm = true
      needs_sqs  = true
    }
  }

  # Filtered map for models that need SQS
  sqs_models = {
    for k, v in local.models : k => v if v.needs_sqs
  }

  # Filtered map for models that need Helm deployments
  helm_models = {
    for k, v in local.models : k => v if v.needs_helm
  }

  # Normalize tags for consistency
  normalized_tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
    Project     = var.project_name
  })

  # Construct shared ECR repository URLs directly without using data source
  repository_urls = {
    for k, v in local.models :
    k => "${var.shared_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-shared-eks-${k}"
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
            # Service account name to be created by Helm in CI/CD
            "${replace(var.oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com",
            "${replace(var.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:eks-processor-${each.value.short_name}"
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
          Effect   = "Allow"
          Action   = ["ecr:GetAuthorizationToken"]
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
            "s3:*",
            "s3:PutBucketCORS"
          ]
          Resource = "*"
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
            "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:*"

          ]
        },
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:GenerateDataKey*"
          ]
          Resource = "*" # Changed from var.kms_key_arn to *
        }
      ]
    )
  })
}

# Custom policy for personhood model to allow Rekognition permissions
resource "aws_iam_role_policy" "personhood_rekognition_policy" {
  count = contains(keys(local.models), "personhood-model") ? 1 : 0

  name = "${var.project_name}-${var.env}-eks-personhood-rekognition-policy"
  role = aws_iam_role.model_role["personhood-model"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:CompareFaces",
          "rekognition:DetectFaces",
          "rekognition:DetectLabels",
          "rekognition:DetectModerationLabels",
          "rekognition:DetectText",
          "rekognition:GetCelebrityInfo",
          "rekognition:RecognizeCelebrities",
          "rekognition:ListCollections",
          "rekognition:ListFaces",
          "rekognition:SearchFaces",
          "rekognition:SearchFacesByImage",
          "rekognition:CreateCollection",
          "rekognition:DeleteCollection",
          "rekognition:IndexFaces",
          "rekognition:DeleteFaces"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Updated code for the assume_shared_role policy section

# Optional: Cross-account role assumption policy
# Add an explicit variable to control creation of these policies
# resource "aws_iam_role_policy" "assume_shared_role" {
#   # Only create if both variables are set appropriately
#   count = 0  # Disable this resource temporarily
#
#   name = "${var.project_name}-${var.env}-eks-${each.key}-assume-shared-role"
#   role = aws_iam_role.model_role[each.key].id
#
#   # Ensure we have a valid ARN format to avoid errors
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = "sts:AssumeRole"
#         Resource = var.shared_role_arn
#       }
#     ]
#   })

# 
#   # Add explicit dependency to ensure the role exists before creating the policy
#   depends_on = [
#     aws_iam_role.model_role
#   ]
# }

# Create Kubernetes service accounts for models
# resource "kubernetes_service_account" "model_service_accounts" {
#   for_each = local.helm_models

#   metadata {
#     name      = "eks-${each.value.short_name}"
#     namespace = var.namespace
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.model_role[each.key].arn
#     }
#     labels = {
#       "app.kubernetes.io/name"       = "eks-${each.value.short_name}"
#       "app.kubernetes.io/managed-by" = "terraform"
#       "app.kubernetes.io/part-of"    = var.project_name
#       "environment"                  = var.env
#     }
#   }

#   automount_service_account_token = true
# }

# Using Helm to deploy models (simplified to avoid templatefile)
resource "helm_release" "model_deployments" {
  for_each = var.enable_helm_deployments ? local.helm_models : tomap({})

  name      = "eks-${each.value.short_name}"
  namespace = var.namespace
  # Use the local Helm chart
  chart      = "${path.module}/chart"

  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = var.helm_timeout

  # Use inline values instead of templatefile
  set {
    name  = "image.repository"
    value = local.repository_urls[each.key]
  }

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  set {
    name  = "replicas"
    value = lookup(var.model_replicas, each.key, var.replicas)
  }

  set {
    name  = "serviceAccount.name"
    value = "eks-processor-${each.value.short_name}"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.model_role[each.key].arn
  }

  set {
    name  = "env.AWS_REGION"
    value = var.aws_region
  }

  set {
    name  = "env.ENVIRONMENT"
    value = var.env
  }

  set {
    name  = "env.MODEL_NAME"
    value = each.key
  }

  set {
    name  = "env.DB_CLUSTER_ARN"
    value = var.aurora_cluster_arn
  }

  set {
    name  = "env.DB_SECRET_ARN"
    value = var.aurora_secret_arn
  }

  set {
    name  = "env.DB_NAME"
    value = var.aurora_database_name
  }

  # Conditionally set SQS URL if needed
  dynamic "set" {
    for_each = each.value.needs_sqs ? [1] : []
    content {
      name  = "env.SQS_QUEUE_URL"
      value = lookup(var.sqs_queues, each.key, "")
    }
  }

  # Resource limits
  set {
    name  = "resources.limits.cpu"
    value = var.cpu_limit
  }

  set {
    name  = "resources.limits.memory"
    value = var.memory_limit
  }

  set {
    name  = "resources.requests.cpu"
    value = var.cpu_request
  }

  set {
    name  = "resources.requests.memory"
    value = var.memory_request
  }

  # GPU tolerations for GPU models
  dynamic "set" {
    for_each = contains(["feature-extraction-model", "image-classification-model", "similarity-model", "evidence-model"], each.key) ? [1] : []
    content {
      name  = "tolerations[0].key"
      value = "nvidia.com/gpu"
    }
  }

  dynamic "set" {
    for_each = contains(["feature-extraction-model", "image-classification-model", "similarity-model", "evidence-model"], each.key) ? [1] : []
    content {
      name  = "tolerations[0].value"
      value = "true"
    }
  }

  dynamic "set" {
    for_each = contains(["feature-extraction-model", "image-classification-model", "similarity-model", "evidence-model"], each.key) ? [1] : []
    content {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    }
  }

  # Node selector for evidence model
  dynamic "set" {
    for_each = lookup(each.value, "dedicated_nodes", false) ? [1] : []
    content {
      name  = "nodeSelector.node-type"
      value = "high-power-gpu"
    }
  }

  dynamic "set" {
    for_each = lookup(each.value, "dedicated_nodes", false) ? [1] : []
    content {
      name  = "nodeSelector.workload-type"
      value = "evidence-model"
    }
  }

  # Node affinity for on-demand nodes (when use_ondemand_nodes is true)
  dynamic "set" {
    for_each = var.use_ondemand_nodes ? [1] : []
    content {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
      value = "node-type"
    }
  }

  dynamic "set" {
    for_each = var.use_ondemand_nodes ? [1] : []
    content {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
      value = "In"
    }
  }

  dynamic "set" {
    for_each = var.use_ondemand_nodes ? [1] : []
    content {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
      value = "gpu-ondemand"
    }
  }

  depends_on = [
    aws_iam_role.model_role,
    aws_iam_role_policy.model_policies
  ]
}

# Get current account ID
data "aws_caller_identity" "current" {}

# Outputs
output "model_role_arns" {
  description = "ARNs of the IAM roles created for EKS models"
  value = {
    for k, v in aws_iam_role.model_role : k => v.arn
  }
}

output "all_role_arns" {
  description = "List of all IAM role ARNs for EKS models"
  value       = values(aws_iam_role.model_role)[*].arn
}

output "helm_releases" {
  description = "Names of the deployed Helm releases"
  value = var.enable_helm_deployments ? {
    for k, v in helm_release.model_deployments : k => v.name
  } : {}
}

# output "service_account_names" {
#   description = "Names of the Kubernetes service accounts created"
#   value = {
#     for k, v in kubernetes_service_account.model_service_accounts : k => v.metadata[0].name
#   }
# }
