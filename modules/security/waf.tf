# security/waf.tf

resource "aws_wafv2_web_acl" "api_waf" {
  name        = "${var.project_name}-${var.env}-api-waf"
  description = "WAF ACL for API Gateway protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule to block bad bots
  rule {
    name     = "BlockBadBots"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockBadBotsMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule to block common vulnerabilities
  rule {
    name     = "BlockCommonVulnerabilities"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockCommonVulnerabilitiesMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule to block known bad inputs
  rule {
    name     = "BlockKnownBadInputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockKnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting rule
  rule {
    name     = "RateLimit"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # SQL injection protection
  rule {
    name     = "BlockSQLInjection"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockSQLInjectionMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "APIWAFMetrics"
    sampled_requests_enabled   = true
  }

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

# CloudWatch logging for WAF
# CloudWatch logging for WAF
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.project_name}-${var.env}"  # Changed format
  retention_in_days = 365
}

# Enable WAF logging with kinesis_firehose_config
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn           = aws_wafv2_web_acl.api_waf.arn

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      requirement = "MEETS_ANY"
    }
  }
}

# Output the WAF ACL ID for use in other modules
output "waf_acl_id" {
  description = "The ID of the WAF ACL"
  value       = aws_wafv2_web_acl.api_waf.id
}

# Output the WAF ACL ARN for use in other modules
output "waf_acl_arn" {
  description = "The ARN of the WAF ACL"
  value       = aws_wafv2_web_acl.api_waf.arn
}

# Variables file (security/variables.tf)
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "env" {
  description = "Environment (dev, staging, prod)"
  type        = string
}
