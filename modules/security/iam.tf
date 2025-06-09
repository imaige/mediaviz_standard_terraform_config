# Get AWS account info

# Get the SSO admin instance
data "aws_ssoadmin_instances" "this" {}


# Create admin group conditionally
resource "aws_identitystore_group" "eks_admins" {
  count = var.enable_sso && length(try(data.aws_ssoadmin_instances.this.identity_store_ids, [])) > 0 ? 1 : 0

  display_name      = "${var.project_name}-${var.env}-eks-admins"
  description       = "EKS administrators group"
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# Get existing user from Identity Store conditionally
data "aws_identitystore_user" "dmitrii" {
  count = var.enable_sso && length(try(data.aws_ssoadmin_instances.this.identity_store_ids, [])) > 0 ? 1 : 0

  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = "dmitrii"
    }
  }
}

# Add user to the group conditionally
resource "aws_identitystore_group_membership" "dmitrii" {
  count = var.enable_sso && length(try(data.aws_ssoadmin_instances.this.identity_store_ids, [])) > 0 ? 1 : 0

  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  group_id          = aws_identitystore_group.eks_admins[0].group_id
  member_id         = data.aws_identitystore_user.dmitrii[0].user_id
}

# Create permission set conditionally
resource "aws_ssoadmin_permission_set" "eks_admin" {
  count = var.enable_sso && length(try(data.aws_ssoadmin_instances.this.arns, [])) > 0 ? 1 : 0

  name             = "eks-admin-${var.env}"
  description      = "EKS administrator permissions for ${var.project_name}"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H"
}

# Create an IAM role for EKS admins - this doesn't depend on SSO
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
            var.github_actions_role_arn,
            "arn:aws:iam::054037110591:role/MediaViz-Backend-Developers-Role" # Management account role
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

# Add EKS admin permissions - this doesn't depend on SSO
resource "aws_iam_role_policy_attachment" "eks_admin_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_admin.name
}

# Create custom policy for additional EKS permissions - this doesn't depend on SSO
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

# Add inline policy to permission set conditionally
resource "aws_ssoadmin_permission_set_inline_policy" "eks_admin" {
  count = var.enable_sso && length(try(data.aws_ssoadmin_instances.this.arns, [])) > 0 ? 1 : 0

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.eks_admin[0].arn

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

# Assign the permission set to the group conditionally
resource "aws_ssoadmin_account_assignment" "eks_admin" {
  count = var.enable_sso && length(try(data.aws_ssoadmin_instances.this.arns, [])) > 0 ? 1 : 0

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.eks_admin[0].arn

  principal_id   = aws_identitystore_group.eks_admins[0].group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}