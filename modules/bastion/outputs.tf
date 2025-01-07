# bastion/outputs.tf
output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  description = "Security group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i mediaviz-dev-bastion.pem ubuntu@3.129.70.11"
}

output "tunnel_command" {
  description = "SSH tunnel command for database access"
  value       = "ssh -i mediaviz-dev-bastion.pem -L 5432:mediaviz-serverless-dev-aurora.cluster-cotsmbbj0vgr.us-east-2.rds.amazonaws.com:5432 ubuntu@3.129.70.11"
}