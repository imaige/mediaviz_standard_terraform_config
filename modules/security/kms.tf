# Get current AWS account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# General encryption key for the project
resource "aws_kms_key" "encryption" {
  description             = "${var.project_name}-${var.env}-encryption-key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  multi_region            = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow AWS Services"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" : [
              "rds.${data.aws_region.current.name}.amazonaws.com",
              "secretsmanager.${data.aws_region.current.name}.amazonaws.com",
              "ec2.${data.aws_region.current.name}.amazonaws.com",
              "autoscaling.${data.aws_region.current.name}.amazonaws.com"
            ]
          },
          StringLike = {
            "aws:PrincipalArn" : [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/*"
            ]
          }
        }
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.env}-encryption"
    Environment = var.env
    Terraform   = "true"
  })
}

# KMS alias for easier identification
resource "aws_kms_alias" "encryption" {
  name          = "alias/${var.project_name}-${var.env}-encryption"
  target_key_id = aws_kms_key.encryption.key_id
}

# Key policy for read access
resource "aws_iam_policy" "kms_read_access" {
  name        = "${var.project_name}-${var.env}-kms-read-access"
  description = "Policy to allow reading data encrypted with the project KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = [aws_kms_key.encryption.arn]
      }
    ]
  })
}

# Outputs
output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.encryption.arn
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.encryption.key_id
}

output "kms_read_policy_arn" {
  description = "ARN of the KMS read access policy"
  value       = aws_iam_policy.kms_read_access.arn
}