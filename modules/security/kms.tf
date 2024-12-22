# security/kms.tf

# General encryption key
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "encryption" {
  description             = "${var.project_name}-${var.env}-encryption-key"
  deletion_window_in_days = 7
  enable_key_rotation    = true
  multi_region           = true

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
      # ... rest of the policy statements
    ]
  })

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

# KMS alias
resource "aws_kms_alias" "encryption" {
  name          = "alias/${var.project_name}-${var.env}-encryption"
  target_key_id = aws_kms_key.encryption.key_id
}

# Outputs
output "kms_key_arn" {
  value = aws_kms_key.encryption.arn
}

output "kms_key_id" {
  value = aws_kms_key.encryption.id
}
