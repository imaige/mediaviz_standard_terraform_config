resource "aws_s3_bucket" "image_upload" {
  bucket = "${var.project_name}-${var.env}-uploads"
  
  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "image_upload" {
  bucket = aws_s3_bucket.image_upload.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "image_upload" {
  bucket = aws_s3_bucket.image_upload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "image_upload" {
  bucket = aws_s3_bucket.image_upload.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Enable access logging
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-${var.env}-uploads-logs"
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Add event notifications
resource "aws_s3_bucket_notification" "access_logs_notification" {
  bucket = aws_s3_bucket.access_logs.id
  eventbridge = true
}

# Add encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

# Add public access block
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Add lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 365
    }
  }
}

# Add replication configuration (if needed)
resource "aws_s3_bucket_replication_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate_all"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.replica.arn
      encryption_configuration {
        replica_kms_key_id = var.replica_kms_key_id
      }
    }
  }
}

resource "aws_s3_bucket_logging" "image_upload" {
  bucket = aws_s3_bucket.image_upload.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_upload.id

  eventbridge = true
}

resource "aws_s3_bucket_cors_configuration" "image_upload" {
  bucket = aws_s3_bucket.image_upload.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "image_upload" {
  bucket = aws_s3_bucket.image_upload.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = var.retention_days
    }
  }
}

# Enable replication (if needed)
# resource "aws_s3_bucket_replication_configuration" "image_upload" {
#   count = var.enable_replication ? 1 : 0
  
#   bucket = aws_s3_bucket.image_upload.id
#   role   = aws_iam_role.replication[0].arn

#   rule {
#     id     = "replicate-all"
#     status = "Enabled"

#     destination {
#       bucket = var.destination_bucket_arn
#       encryption_configuration {
#         replica_kms_key_id = var.destination_kms_key_arn
#       }
#     }
#   }
# }

resource "aws_s3_bucket" "replica" {
  bucket = "${var.project_name}-${var.env}-uploads-logs-replica"

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

# Create IAM role for replication
resource "aws_iam_role" "replication_role" {
  name = "${var.project_name}-${var.env}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# Add replication policy to the role
resource "aws_iam_role_policy" "replication" {
  name = "${var.project_name}-${var.env}-s3-replication-policy"
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.access_logs.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.access_logs.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.replica.arn}/*"
        ]
      }
    ]
  })
}

# Configure encryption for replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  bucket = aws_s3_bucket.replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access for replica bucket
resource "aws_s3_bucket_public_access_block" "replica" {
  bucket = aws_s3_bucket.replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Add versioning for replica bucket
resource "aws_s3_bucket_versioning" "replica" {
  bucket = aws_s3_bucket.replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "replica" {
  bucket = aws_s3_bucket.replica.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "log/"
}

# Processed images bucket
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-${var.env}-processed"
}

resource "aws_s3_bucket_cors_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 365
    }
  }
}