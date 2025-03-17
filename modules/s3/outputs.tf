#-------------------------------------------------
# Module Outputs
#-------------------------------------------------
output "bucket_id" {
  description = "ID of the primary S3 bucket"
  value       = aws_s3_bucket.primary.id
}

output "bucket_arn" {
  description = "ARN of the primary S3 bucket"
  value       = aws_s3_bucket.primary.arn
}

output "logs_bucket_id" {
  description = "ID of the logs S3 bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the logs S3 bucket"
  value       = aws_s3_bucket.logs.arn
}

output "processed_bucket_id" {
  description = "ID of the processed images S3 bucket"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "ARN of the processed images S3 bucket"
  value       = aws_s3_bucket.processed.arn
}

output "helm_charts_bucket_id" {
  description = "ID of the Helm charts S3 bucket"
  value       = aws_s3_bucket.helm_charts.id
}

output "helm_charts_bucket_arn" {
  description = "ARN of the Helm charts S3 bucket"
  value       = aws_s3_bucket.helm_charts.arn
}