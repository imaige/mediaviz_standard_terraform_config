# environments/qa/bastion_secret.tf

# Read the private key file directly from the modules path
data "local_file" "bastion_private_key" {
  filename = "${path.module}/../../modules/bastion/bastion_key"
}

# Store the bastion private key in Secrets Manager
resource "aws_secretsmanager_secret" "bastion_ssh_key" {
  name        = "${var.project_name}-${var.env}-bastion-key"
  description = "SSH private key for bastion host access"
  kms_key_id  = module.security.kms_key_arn
  
  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Store the private key in the secret
resource "aws_secretsmanager_secret_version" "bastion_ssh_key" {
  secret_id     = aws_secretsmanager_secret.bastion_ssh_key.id
  secret_string = data.local_file.bastion_private_key.content
}

# Output the secret ARN for easier retrieval
output "bastion_ssh_key_secret_arn" {
  description = "ARN of the secret containing the SSH private key"
  value       = aws_secretsmanager_secret.bastion_ssh_key.arn
}