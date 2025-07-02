# modules/s3/main.tf

locals {
  # Normalize tags to lowercase to prevent case-sensitivity issues
  normalized_tags = merge(
    {
      for key, value in var.tags :
      lower(key) => value
    },
    {
      environment = var.env
      terraform   = "true"
    }
  )

  # Use bucket_suffix if provided, otherwise use default names
  primary_bucket_name     = var.bucket_suffix != "" ? "${var.project_name}-serverless-${var.env}-${var.bucket_suffix}" : "${var.project_name}-${var.env}-uploads"
  logs_bucket_name        = var.bucket_suffix != "" ? "${var.project_name}-serverless-${var.env}-${var.bucket_suffix}-logs" : "${var.project_name}-${var.env}-uploads-logs"
  processed_bucket_name   = var.bucket_suffix != "" ? "${var.project_name}-${var.env}-${var.bucket_suffix}-processed" : "${var.project_name}-${var.env}-processed"
  helm_charts_bucket_name = var.helm_charts_bucket_name != "" ? var.helm_charts_bucket_name : "${var.project_name}-${var.env}-helm-charts"
}

#-------------------------------------------------
# Primary Upload Bucket
#-------------------------------------------------
resource "aws_s3_bucket" "primary" {
  bucket = local.primary_bucket_name

  tags = local.normalized_tags
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket = aws_s3_bucket.primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_cors_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "expiration-rule"
    status = "Enabled"

    # Add a filter block to comply with AWS provider requirements
    filter {
      prefix = "" # Empty prefix applies to all objects
    }

    # Set expiration to max(retention_days, 91) to ensure it's greater than the longest transition period
    expiration {
      days = max(var.retention_days, 91)
    }

    # Storage class transitions
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_notification" "primary" {
  bucket      = aws_s3_bucket.primary.id
  eventbridge = true
}

#-------------------------------------------------
# Logging Bucket
#-------------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket_name

  tags = local.normalized_tags
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "logs" {
  bucket      = aws_s3_bucket.logs.id
  eventbridge = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "cleanup"
    status = "Enabled"
    filter {
      prefix = "" # Empty prefix applies to all objects
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 365
    }
  }
}

# Configure primary bucket to use log bucket
resource "aws_s3_bucket_logging" "primary" {
  bucket = aws_s3_bucket.primary.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "log/"
}

#-------------------------------------------------
# Processed Images Bucket
#-------------------------------------------------
resource "aws_s3_bucket" "processed" {
  bucket = local.processed_bucket_name

  tags = local.normalized_tags
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
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

    filter {
      prefix = "" # Empty prefix applies to all objects
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Ensure expiration is greater than any transition periods that might be added in the future
    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_logging" "processed" {
  bucket = aws_s3_bucket.processed.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "processed-log/"
}

resource "aws_s3_bucket_notification" "processed" {
  bucket      = aws_s3_bucket.processed.id
  eventbridge = true
}

#-------------------------------------------------
# Helm Charts Bucket
#-------------------------------------------------
resource "aws_s3_bucket" "helm_charts" {
  bucket = local.helm_charts_bucket_name

  tags = local.normalized_tags
}

resource "aws_s3_bucket_versioning" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  rule {
    filter {
      prefix = "" # Empty prefix applies to all objects
    }
    id     = "cleanup"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Optional: Add expiration if you want to clean up old chart versions
    expiration {
      days = 365 # Adjust retention period as needed
    }
  }
}

resource "aws_s3_bucket_logging" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "helm-charts-log/"
}

resource "aws_s3_bucket_notification" "helm_charts" {
  bucket      = aws_s3_bucket.helm_charts.id
  eventbridge = true
}

# Cross-account access policy for Helm charts bucket
resource "aws_s3_bucket_policy" "helm_charts" {
  count  = 1
  bucket = aws_s3_bucket.helm_charts.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::515966522375:root" # Use a known valid ARN
        },
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.helm_charts.arn,
          "${aws_s3_bucket.helm_charts.arn}/*"
        ]
      }
    ]
  })
}