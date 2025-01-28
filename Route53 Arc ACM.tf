# The ACM certificate, Route 53 hosted zone were created in the console and referenced in Terraform as data sources.
# Please be cautios with ARC - Application Recovery Controller, as it is an expensive resource
# and should be deployed after you make sure the orther resources work smoothly.
# I will comment it out.

data "aws_acm_certificate" "thread_cert" {
  domain      = "threadcraft.link"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# Reference an existing Route 53 hosted zone by its domain name 

data "aws_route53_zone" "primary" {
  name         = var.hosted_zone_name
  private_zone = false
}

data "aws_acm_certificate" "thread_cert_dr" {
  domain      = "threadcraft.link"
  types       = ["AMAZON_ISSUED"]
  provider    = aws.backup
  most_recent = true
}

# Create an Alias record to point to ALB 
resource "aws_route53_record" "primary_alb_alias" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.domain_name_alb
  type    = "A"

  alias {
    name                   = aws_lb.alb-tier1.dns_name
    zone_id                = aws_lb.alb-tier1.zone_id
    evaluate_target_health = true

  }
  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  #health_check_id = aws_route53_health_check.primary_health_check.id

}

# Create an Alias record to point to ALB recovery
resource "aws_route53_record" "secondary_alb_alias" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.domain_name_alb
  type    = "A"

  alias {
    name                   = aws_lb.recov_alb-tier1.dns_name
    zone_id                = aws_lb.recov_alb-tier1.zone_id
    evaluate_target_health = true
  }

  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  #health_check_id = aws_route53_health_check.secondary_health_check.id
}


# Create Route 53 Recovery Control Configuration

# Route 53 ARC Configuration


/*
resource "aws_route53recoveryreadiness_recovery_group" "thread_recovery_group" {
  recovery_group_name = "thread-recovery-group"
  cells = [
    aws_route53recoveryreadiness_cell.thread_recovery_cell_east.arn,
    aws_route53recoveryreadiness_cell.thread_recovery_cell_west.arn

  ]
}

resource "aws_route53recoveryreadiness_cell" "thread_recovery_cell_east" {
  cell_name               = "thread-recovery-cell-east"
  parent_readiness_scopes = [aws_route53recoveryreadiness_recovery_group.thread_recovery_group.arn]

}

resource "aws_route53recoveryreadiness_cell" "thread_recovery_cell_west" {
  cell_name               = "thread-recovery-cell-west"
  parent_readiness_scopes = [aws_route53recoveryreadiness_recovery_group.thread_recovery_group.arn]

}

resource "aws_route53recoveryreadiness_resource_set" "alb_resource_set" {
  resource_set_name = "alb-resource-set"
  resource_set_type = "AWS::ElasticLoadBalancing::LoadBalancer"

  resources {
    resource_arn = aws_lb.alb-tier1.arn
  }

  resources {
    resource_arn = aws_lb.recov_alb-tier1.arn
  }
}


resource "aws_route53recoveryreadiness_readiness_check" "app_readiness_check" {
  readiness_check_name = "app-readiness-check"
  resource_set_name    = aws_route53recoveryreadiness_resource_set.app_resource_set.resource_set_name
  tags = {
    Name = "app-readiness-check"
  }
}


resource "aws_route53recoverycontrolconfig_cluster" "recovery" {
  name = "application-cluster"
}

resource "aws_route53recoverycontrolconfig_control_panel" "recovery" {
  name        = "application-panel"
  cluster_arn = aws_route53recoverycontrolconfig_cluster.recovery.arn
}

resource "aws_route53recoverycontrolconfig_routing_control" "primary" {
  name              = "primary-region"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.recovery.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.recovery.arn
}

resource "aws_route53recoverycontrolconfig_routing_control" "secondary" {
  name              = "secondary-region"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.recovery.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.recovery.arn
}


resource "aws_route53recoverycontrolconfig_safety_rule" "safety_rule" {
  asserted_controls = [aws_route53recoverycontrolconfig_routing_control.primary.arn, aws_route53recoverycontrolconfig_routing_control.secondary.arn]
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.recovery.arn
  name              = "AtLeastOneHealthy"
  wait_period_ms    = 5000

  rule_config {
    inverted  = false
    threshold = 1
    type      = "ATLEAST"
  }
}


resource "aws_route53_health_check" "primary_health_check" {
  type                = "RECOVERY_CONTROL"
  routing_control_arn = aws_route53recoverycontrolconfig_routing_control.primary.arn
  invert_healthcheck  = false
}

resource "aws_route53_health_check" "secondary_health_check" {
  type                = "RECOVERY_CONTROL"
  routing_control_arn = aws_route53recoverycontrolconfig_routing_control.secondary.arn
  invert_healthcheck  = false
}

*/

# health checks for failover
resource "aws_route53_health_check" "alb_primary_health_check" {
  type                = "https"
  port                = 443
  resource_path       = "/index.html"
  fqdn                = aws_lb.alb-tier1.dns_name
  request_interval    = 30
  failure_threshold   = 3
}

resource "aws_route53_health_check" "alb_secondary_health_check" {
  type                = "https"
  port                = 443
  resource_path       = "/index.html"
  fqdn                = aws_lb.recov_alb-tier1.dns_name
  request_interval    = 30
  failure_threshold   = 3
}



# CloudWatch Alarms for Primary Region
resource "aws_cloudwatch_metric_alarm" "primary_alb_health" {
  alarm_name          = "primary-alb-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "30"
  statistic           = "Average"
  threshold           = "1"
  treat_missing_data  = "ignore"
  alarm_description   = "Primary ALB health check"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.alb-tier1.arn
  }
}
resource "aws_cloudwatch_metric_alarm" "primary_asg_health" {
  alarm_name          = "primary-asg-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/AutoScaling"
  period              = "30"
  statistic           = "Average"
  threshold           = "1"
  treat_missing_data  = "ignore"
  alarm_description   = "Primary ASG health check"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg-tier1.name
  }
}

# CloudWatch Alarms for Secondary Region
resource "aws_cloudwatch_metric_alarm" "secondary_alb_health" {
  alarm_name          = "secondary-alb-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "30"
  statistic           = "Average"
  threshold           = "1"
  treat_missing_data  = "ignore"
  alarm_description   = "Secondary ALB health check"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.recov_alb-tier1.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "secondary_asg_health" {
  alarm_name          = "secondary-asg-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/AutoScaling"
  period              = "30"
  statistic           = "Average"
  threshold           = "1"
  treat_missing_data  = "ignore"
  alarm_description   = "Secondary ASG health check"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.recov_asg-tier1.name
  }
}

# CloudWatch alarms for the route53 health checks
resource "aws_cloudwatch_metric_alarm" "primary_health_check_alarm" {
  alarm_name          = "Primary-HealthCheck-Unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 30
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Triggered when the primary health check is unhealthy."
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb_primary_health_check.id
  }
}

resource "aws_cloudwatch_metric_alarm" "secondary_health_check_alarm" {
  alarm_name          = "Secondary-HealthCheck-Healthy"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 30
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Triggered when the secondary health check becomes healthy."
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb_secondary_health_check.id
  }
}


# SNS Topic for alerts
resource "aws_sns_topic" "infrastructure_alerts" {
  name = "infrastructure-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.infrastructure_alerts.arn
  protocol  = "email"
  endpoint  = var.email
}

data "aws_iam_policy_document" "dr_subscription_policy" {
  statement {
    actions = [
      "sns:AddPermission",
      "sns:DeleteTopic",
      "sns:GetDataProtectionPolicy",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:Publish",
      "sns:PutDataProtectionPolicy",
      "sns:RemovePermission",
      "sns:SetTopicAttributes",
      "sns:Subscribe"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    resources = [aws_sns_topic.infrastructure_alerts.arn]
  }
}

# Attach Policy to SNS Topic
resource "aws_sns_topic_policy" "event_subscription_policy1_attach" {
  arn    = aws_sns_topic.infrastructure_alerts.arn
  policy = data.aws_iam_policy_document.dr_subscription_policy.json
}

