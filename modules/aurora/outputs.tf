output "cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = aws_rds_cluster.aurora.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint for the cluster"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.aurora.arn
}

output "cluster_id" {
  description = "ID of the Aurora cluster"
  value       = aws_rds_cluster.aurora.id
}

output "security_group_id" {
  description = "ID of the Aurora security group"
  value       = aws_security_group.aurora.id
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.aurora.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = aws_kms_key.aurora.arn
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_rds_cluster.aurora.database_name
}


PGPASSWORD='dguCm3C9nH5JbAh8Q&LvMfw*' /opt/homebrew/opt/postgresql@16/bin/pg_dump \
    -h dev-mediaviz.cotsmbbj0vgr.us-east-2.rds.amazonaws.com \
    -p 5432 \
    -U postgres \
    -d postgres \
    --exclude-table-data 'z_*' \
    --exclude-table 'z_*' \
    -n public \
    --no-owner \
    --no-acl \
    | PGPASSWORD=nwkejC33ysojuKMz /opt/homebrew/opt/postgresql@16/bin/psql \
    -h localhost \
    -p 5433 \
    -U postgres \
    -d imaige