resource "aws_cloudwatch_event_rule" "image_upload" {
  name        = "${var.project_name}-${var.env}-image-upload"
  description = "Capture image upload events with client_id"

  event_pattern = jsonencode({
    source      = ["custom.imageUpload"]
    detail-type = ["ImageUploaded"]
  })
}

resource "aws_cloudwatch_event_target" "sqs" {
  rule      = aws_cloudwatch_event_rule.image_upload.name
  target_id = "ProcessImageQueue"
  arn       = var.target_arn
}