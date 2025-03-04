# Get AWS account info

# Get the SSO admin instance
data "aws_ssoadmin_instances" "this" {}

# Create admin group
resource "aws_identitystore_group" "eks_admins" {
  display_name = "${var.project_name}-${var.env}-eks-admins"
  description  = "EKS administrators group"
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# Get existing user from Identity Store
data "aws_identitystore_user" "dmitrii" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  
  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = "dmitrii"
    }
  }
}

# Add user to the group
resource "aws_identitystore_group_membership" "dmitrii" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  group_id         = aws_identitystore_group.eks_admins.group_id
  member_id        = data.aws_identitystore_user.dmitrii.user_id
}

# Create permission set for EKS admins
resource "aws_ssoadmin_permission_set" "eks_admin" {
  name             = "eks-admin-${var.env}"
  description      = "EKS administrator permissions for ${var.project_name}"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H"
}

# Create an IAM role for EKS admins
resource "aws_iam_role" "eks_admin" {
  name = "${var.project_name}-${var.env}-eks-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
            aws_iam_role.github_actions.arn  # Add GitHub Actions role as a trusted entity
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-eks-admin"
  })
}

# Add EKS admin permissions
resource "aws_iam_role_policy_attachment" "eks_admin_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_admin.name
}

# resource "aws_iam_role_policy_attachment" "eks_admin_console" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSConsoleFullAccess"
#   role       = aws_iam_role.eks_admin.name
# }

# Create custom policy for additional EKS permissions
resource "aws_iam_role_policy" "eks_admin_custom" {
  name = "${var.project_name}-${var.env}-eks-admin-custom"
  role = aws_iam_role.eks_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:DescribeInstances",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
          "ec2:DescribeVpcs",
          "ec2:DescribeNetworkInterfaces",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:ListUsers",
          "iam:ListGroups",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Add inline policy to permission set to allow assuming the EKS admin role
resource "aws_ssoadmin_permission_set_inline_policy" "eks_admin" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.eks_admin.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          aws_iam_role.eks_admin.arn
        ]
      }
    ]
  })
}

# Assign the permission set to the group
resource "aws_ssoadmin_account_assignment" "eks_admin" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.eks_admin.arn

  principal_id   = aws_identitystore_group.eks_admins.group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}

# Create OIDC Provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"  # GitHub's OIDC thumbprint
  ]

  tags = {
    Name = "${var.project_name}-${var.env}-github-oidc"
  }
}

# Create IAM role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.env}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub": "repo:imaige/*:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.env}-github-actions"
  }
}

# Add policy for ECR access
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${var.project_name}-${var.env}-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      }
    ]
  })
}

# Add policy for S3 access (for Helm charts)
resource "aws_iam_role_policy" "github_actions_s3" {
  name = "${var.project_name}-${var.env}-github-actions-s3"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.env}-helm-charts",
          "arn:aws:s3:::${var.project_name}-${var.env}-helm-charts/*"
        ]
      }
    ]
  })
}

# Add policy for KMS access
resource "aws_iam_role_policy" "github_actions_kms" {
  name = "${var.project_name}-${var.env}-github-actions-kms"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Add policy for EKS access and Helm deployment
resource "aws_iam_role_policy" "github_actions_eks" {
  name = "${var.project_name}-${var.env}-github-actions-eks"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion"
        ]
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:ListClusters",
          "eks:ListFargateProfiles",
          "eks:ListNodegroups",
          "eks:ListUpdates",
          "eks:ListAddons"
        ]
        Resource = "*"
      }
    ]
  })
}

# Add policy to allow assuming the EKS admin role
resource "aws_iam_role_policy" "github_actions_assume_eks_admin" {
  name = "${var.project_name}-${var.env}-github-actions-assume-eks-admin"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = aws_iam_role.eks_admin.arn
      }
    ]
  })
}

# Update EKS admin role trust policy to allow GitHub Actions
# resource "aws_iam_role_policy_attachment" "eks_admin_trust_github" {
#   policy_arn = aws_iam_role.eks_admin.arn
#   role       = aws_iam_role.github_actions.name
# }

# Add necessary permissions for managing k8s resources
resource "aws_iam_role_policy" "github_actions_k8s" {
  name = "${var.project_name}-${var.env}-github-actions-k8s"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:ListUpdates",
          "eks:ListFargateProfiles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListRoles",
          "iam:ListPolicies"
        ]
        Resource = "*"
      }
    ]
  })
}