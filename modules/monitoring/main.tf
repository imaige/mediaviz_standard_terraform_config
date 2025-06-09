# AWS Managed Prometheus (AMP)
resource "aws_prometheus_workspace" "main" {
  alias = "${var.project_name}-${var.env}-prometheus"
  
  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.prometheus_logs.arn}:*"
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.env}-prometheus"
    Environment = var.env
    ManagedBy   = "terraform"
    Service     = "prometheus"
  })
}

# CloudWatch Log Group for Prometheus
resource "aws_cloudwatch_log_group" "prometheus_logs" {
  name              = "/aws/prometheus/${var.project_name}-${var.env}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.env}-prometheus-logs"
    Environment = var.env
    ManagedBy   = "terraform"
  })
}

# AWS Managed Grafana (AMG)
resource "aws_grafana_workspace" "main" {
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type         = "SERVICE_MANAGED"
  name                    = "${var.project_name}-${var.env}-grafana"
  description             = "Grafana workspace for ${var.project_name} ${var.env} environment"
  role_arn                = aws_iam_role.grafana_role.arn
  
  data_sources = ["PROMETHEUS", "CLOUDWATCH"]
  
  notification_destinations = var.notification_destinations

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.env}-grafana"
    Environment = var.env
    ManagedBy   = "terraform"
    Service     = "grafana"
  })
}

# Grafana Data Source for Prometheus
resource "aws_grafana_workspace_api_key" "prometheus_access" {
  count                = var.create_prometheus_datasource ? 1 : 0
  key_name             = "prometheus-access"
  key_role             = "ADMIN"
  seconds_to_live      = var.api_key_seconds_to_live
  workspace_id         = aws_grafana_workspace.main.id
}

# IAM Role for Grafana to access Prometheus and CloudWatch
resource "aws_iam_role" "grafana_role" {
  name = "${var.project_name}-${var.env}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Grafana to access Prometheus
resource "aws_iam_role_policy" "grafana_prometheus_policy" {
  name = "${var.project_name}-${var.env}-grafana-prometheus-policy"
  role = aws_iam_role.grafana_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata"
        ]
        Resource = [
          aws_prometheus_workspace.main.arn,
          "${aws_prometheus_workspace.main.arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for Grafana to access CloudWatch
resource "aws_iam_role_policy" "grafana_cloudwatch_policy" {
  name = "${var.project_name}-${var.env}-grafana-cloudwatch-policy"
  role = aws_iam_role.grafana_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogRecord"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Prometheus to scrape EKS metrics
resource "aws_iam_role" "prometheus_scraping_role" {
  count = var.enable_eks_integration ? 1 : 0
  name  = "${var.project_name}-${var.env}-prometheus-scraping-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:${var.prometheus_namespace}:${var.prometheus_service_account}"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Prometheus scraping
resource "aws_iam_role_policy" "prometheus_scraping_policy" {
  count = var.enable_eks_integration ? 1 : 0
  name  = "${var.project_name}-${var.env}-prometheus-scraping-policy"
  role  = aws_iam_role.prometheus_scraping_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:QueryMetrics",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = [
          aws_prometheus_workspace.main.arn,
          "${aws_prometheus_workspace.main.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Alarm for Prometheus workspace health
resource "aws_cloudwatch_metric_alarm" "prometheus_health" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.env}-prometheus-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ActiveSeries"
  namespace           = "AWS/Prometheus"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors prometheus workspace health"
  alarm_actions       = var.cloudwatch_alarm_actions

  dimensions = {
    WorkspaceId = aws_prometheus_workspace.main.id
  }

  tags = var.tags
}

# Security Group for Grafana workspace (if VPC is configured)
resource "aws_security_group" "grafana" {
  count       = var.vpc_id != "" ? 1 : 0
  name        = "${var.project_name}-${var.env}-grafana-sg"
  description = "Security group for Grafana workspace"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.grafana_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-grafana-sg"
  })
}

# Kubernetes namespace for monitoring
resource "kubernetes_namespace" "monitoring" {
  count = var.enable_eks_integration && var.deploy_prometheus_to_eks ? 1 : 0
  
  metadata {
    name = var.prometheus_namespace
    
    labels = {
      name = var.prometheus_namespace
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Kubernetes service account for Prometheus
resource "kubernetes_service_account" "prometheus" {
  count = var.enable_eks_integration && var.deploy_prometheus_to_eks ? 1 : 0
  
  metadata {
    name      = var.prometheus_service_account
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.prometheus_scraping_role[0].arn
    }
    
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [aws_iam_role.prometheus_scraping_role]
}

# Helm release for Prometheus
resource "helm_release" "prometheus" {
  count      = var.enable_eks_integration && var.deploy_prometheus_to_eks ? 1 : 0
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = var.prometheus_chart_version
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  values = [
    templatefile("${path.module}/helm-values/prometheus.yaml", {
      prometheus_role_arn         = aws_iam_role.prometheus_scraping_role[0].arn
      prometheus_remote_write_url = aws_prometheus_workspace.main.prometheus_endpoint
      aws_region                  = var.aws_region
      cluster_name               = var.cluster_name
    })
  ]

  depends_on = [
    kubernetes_service_account.prometheus,
    aws_prometheus_workspace.main
  ]
}