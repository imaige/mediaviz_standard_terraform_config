resource "aws_signer_signing_profile" "lambda" {
  name_prefix = "${var.env}"
  platform_id = "AWSLambda-SHA384-ECDSA"
}
