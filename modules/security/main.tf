resource "aws_signer_signing_profile" "lambda" {
  name_prefix = "${var.project_name}-${var.env}"
  platform_id = "AWSLambda-SHA384-ECDSA"
}
