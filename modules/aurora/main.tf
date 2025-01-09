# Aurora Serverless v2 Module main.tf

# KMS key for encryption
resource "aws_kms_key" "aurora" {
  description             = "KMS key for Aurora cluster ${var.project_name}-${var.env}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.project_name}-${var.env}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

# Random password for master user
resource "random_password" "master" {
  length  = 16
  special = false
}

# Store master credentials in Secrets Manager
resource "aws_secretsmanager_secret" "aurora" {
  name = "${var.project_name}-${var.env}-aurora-credentials-pg"
  kms_key_id = aws_kms_key.aurora.arn

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

resource "aws_secretsmanager_secret_version" "aurora" {
  secret_id = aws_secretsmanager_secret.aurora.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora.endpoint
    port     = aws_rds_cluster.aurora.port
    dbname   = var.database_name
  })
}

# Subnet group
resource "aws_db_subnet_group" "aurora" {
  name        = "${var.project_name}-${var.env}-aurora"
  description = "Subnet group for Aurora Serverless v2"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Security group for Aurora
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.env}-aurora-sg"
  description = "Security group for Aurora Serverless v2"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Allow inbound PostgreSQL access from Lambda security groups
resource "aws_security_group_rule" "aurora_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.lambda_security_group_id
  security_group_id        = aws_security_group.aurora.id
  description             = "Allow PostgreSQL access from Lambda functions"
}

resource "aws_security_group_rule" "aurora_public_access" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.aurora.id
  description       = "Allow public PostgreSQL access"
}

# Parameter group
resource "aws_rds_cluster_parameter_group" "aurora" {
  family = "aurora-postgresql16"
  name   = "${var.project_name}-${var.env}-aurora-pg-16"  #

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries that take more than 1 second
  }

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier     = "${var.project_name}-${var.env}-aurora"
  engine                = "aurora-postgresql"
  engine_mode           = "provisioned"
  engine_version        = var.engine_version
  database_name         = var.database_name
  master_username       = var.master_username
  master_password       = random_password.master.result
  
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.aurora.arn

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # Backup configuration
  backup_retention_period = var.backup_retention_days
  preferred_backup_window = var.backup_window
  copy_tags_to_snapshot  = true
  allow_major_version_upgrade = true 
  
  # Maintenance window
  preferred_maintenance_window = var.maintenance_window
  
  # Enable Data API
#   enable_http_endpoint = true

  # Use custom parameter group
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  # Enable deletion protection in production
  deletion_protection = var.env == "prod" ? true : false

  skip_final_snapshot = var.env != "prod"
  final_snapshot_identifier = var.env == "prod" ? "${var.project_name}-${var.env}-aurora-final-${formatdate("YYYY-MM-DD-hh-mm", timestamp())}" : null

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# Aurora Serverless v2 Instance
resource "aws_rds_cluster_instance" "aurora" {
  count = var.instance_count

  identifier         = "${var.project_name}-${var.env}-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  
  instance_class     = "db.serverless"
  engine            = aws_rds_cluster.aurora.engine
  engine_version    = aws_rds_cluster.aurora.engine_version
  publicly_accessible = var.publicly_accessible

  # Enable Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.aurora.arn
  
  # Enable enhanced monitoring
  monitoring_interval = 30
  monitoring_role_arn = aws_iam_role.enhanced_monitoring.arn

  tags = merge(var.tags, {
    Environment = var.env
    Terraform   = "true"
  })
}

# IAM role for enhanced monitoring
# IAM role for enhanced monitoring
resource "aws_iam_role" "enhanced_monitoring" {
  name = "${var.project_name}-${var.env}-aurora-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  # Use only the provider-level default tags
  tags = {
    Name = "${var.project_name}-${var.env}-aurora-monitoring"
  }
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  role       = aws_iam_role.enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Allow inbound PostgreSQL access from EKS nodes
resource "aws_security_group_rule" "aurora_eks_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.eks_node_security_group_id
  security_group_id        = aws_security_group.aurora.id
  description             = "Allow PostgreSQL access from EKS nodes"
}