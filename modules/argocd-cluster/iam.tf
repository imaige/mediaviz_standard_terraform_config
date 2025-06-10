# IAM configuration for ArgoCD cluster manager

# IAM role for ArgoCD cluster manager
resource "aws_iam_role" "argocd_cluster_manager" {
  count = var.create_argocd_service_account ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-cluster-manager-role"

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
            "${replace(var.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:${var.argocd_namespace}:${var.argocd_service_account_name}"
          }
        }
      }
    ]
  })

  tags = local.normalized_tags
}

# Policy for ECR access
resource "aws_iam_role_policy" "argocd_ecr_policy" {
  count = var.create_argocd_service_account ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-cluster-ecr-policy"
  role = aws_iam_role.argocd_cluster_manager[0].id

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
          "arn:aws:ecr:${data.aws_region.current.name}:${var.shared_account_id}:repository/${var.project_name}-shared-${repo}"
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
  count = var.create_argocd_service_account && var.helm_charts_bucket_name != "" ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-cluster-s3-policy"
  role = aws_iam_role.argocd_cluster_manager[0].id

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

# Policy for cross-account role assumption
resource "aws_iam_role_policy" "argocd_cross_account_policy" {
  count = var.create_argocd_service_account && var.cross_account_role_arn != "" ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-cluster-cross-account-policy"
  role = aws_iam_role.argocd_cluster_manager[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [var.cross_account_role_arn]
      }
    ]
  })
}

# Policy for KMS access
resource "aws_iam_role_policy" "argocd_kms_policy" {
  count = var.create_argocd_service_account && length(var.kms_key_arns) > 0 ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-cluster-kms-policy"
  role = aws_iam_role.argocd_cluster_manager[0].id

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

# Policy for Secrets Manager access
resource "aws_iam_role_policy" "argocd_secrets_policy" {
  count = var.create_argocd_service_account ? 1 : 0
  
  name = "${var.project_name}-${var.env}-argocd-cluster-secrets-policy"
  role = aws_iam_role.argocd_cluster_manager[0].id

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
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-*"
        ]
      }
    ]
  })
}