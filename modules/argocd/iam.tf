# IAM roles and policies for ArgoCD

# IAM role for ArgoCD server
resource "aws_iam_role" "argocd_server" {
  name = "${var.project_name}-${var.env}-argocd-server-role"

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
            "${replace(var.oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(var.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:${var.argocd_namespace}:argocd-server"
          }
        }
      }
    ]
  })

  tags = local.normalized_tags
}

# IAM role for ArgoCD application controller  
resource "aws_iam_role" "argocd_controller" {
  name = "${var.project_name}-${var.env}-argocd-controller-role"

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
            "${replace(var.oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(var.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:${var.argocd_namespace}:argocd-application-controller"
          }
        }
      }
    ]
  })

  tags = local.normalized_tags
}

# Policy for ECR access
resource "aws_iam_role_policy" "argocd_ecr_policy" {
  name = "${var.project_name}-${var.env}-argocd-ecr-policy"
  role = aws_iam_role.argocd_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
        Resource = [
          for repo in var.shared_ecr_repositories :
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-shared-${repo}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      }
    ]
  })
}

# Policy for S3 Helm charts access
resource "aws_iam_role_policy" "argocd_s3_policy" {
  count = var.helm_charts_bucket_name != "" ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-s3-policy"
  role = aws_iam_role.argocd_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.helm_charts_bucket_name}",
          "arn:aws:s3:::${var.helm_charts_bucket_name}/*"
        ]
      }
    ]
  })
}

# Policy for cross-account cluster access
resource "aws_iam_role_policy" "argocd_cross_account_policy" {
  count = length(var.external_cluster_configs) > 0 ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-cross-account-policy"
  role = aws_iam_role.argocd_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          for config in var.external_cluster_configs :
          config.cross_account_role_arn
        ]
      }
    ]
  })
}

# Policy for KMS access
resource "aws_iam_role_policy" "argocd_kms_policy" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-kms-policy"
  role = aws_iam_role.argocd_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*"
        ]
        Resource = var.kms_key_arns
      }
    ]
  })
}

# Policy for Secrets Manager access (for external cluster credentials)
resource "aws_iam_role_policy" "argocd_secrets_policy" {
  name = "${var.project_name}-${var.env}-argocd-secrets-policy"
  role = aws_iam_role.argocd_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-*"
        ]
      }
    ]
  })
}