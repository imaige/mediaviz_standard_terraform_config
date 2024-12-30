resource "aws_s3_bucket" "image_upload" {
  bucket = "${var.project_name}-${var.env}-uploads"
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

    expiration {
      days = var.retention_days
    }
  }
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

    expiration {
      days = var.retention_days
    }
  }
}