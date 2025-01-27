
# Primary KMS Key (East Region)
data "aws_kms_key" "by_alias_east" {
  key_id = "alias/primary_key"
}

# Secondary KMS Key (West Region for Replica)
data "aws_kms_key" "by_alias_west" {
  key_id   = "alias/secondary_key"
  provider = aws.backup
}

# Declare the data source for Availability Zones

data "aws_availability_zones" "recovery_available" {
  provider = aws.backup
  state    = "available"
}
# Database tier 3

resource "aws_rds_global_cluster" "global_aurora" {
  global_cluster_identifier = "global-aurora"
  engine                    = "aurora-mysql"
  engine_version            = var.db_engine_version
  database_name             = "example_db"
  storage_encrypted         = true


}

resource "aws_rds_cluster" "aurora-cluster" {
  database_name             = var.db_name
  cluster_identifier        = "aurora-primary-cluster"
  engine                    = aws_rds_global_cluster.global_aurora.engine
  engine_version            = aws_rds_global_cluster.global_aurora.engine_version
  master_username           = var.db_username
  master_password           = var.db_password
  skip_final_snapshot       = true
  backup_retention_period   = 7
  db_subnet_group_name      = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids    = [aws_security_group.db-tier3.id]
  global_cluster_identifier = aws_rds_global_cluster.global_aurora.id
  kms_key_id                = data.aws_kms_key.by_alias_east.arn

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = "production"
  }

}

# DB subnet group for RDS 
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet5.id, aws_subnet.private_subnet6.id]
  tags       = local.common_tags
}

resource "aws_rds_cluster_instance" "aurora-instance" {
  identifier         = "aurora-instance"
  cluster_identifier = aws_rds_cluster.aurora-cluster.cluster_identifier
  engine             = aws_rds_cluster.aurora-cluster.engine
  instance_class     = var.db_instance_type


}

# Database tier 3 - recovery

resource "aws_rds_cluster" "recovery-aurora-cluster" {
  provider                       = aws.backup
  cluster_identifier             = "aurora-secondary-cluster"
  engine                         = aws_rds_global_cluster.global_aurora.engine
  engine_version                 = aws_rds_global_cluster.global_aurora.engine_version
  skip_final_snapshot            = true
  backup_retention_period        = 7
  db_subnet_group_name           = aws_db_subnet_group.recovery_db_subnet_group.name
  vpc_security_group_ids         = [aws_security_group.recovery_db-tier3.id]
  global_cluster_identifier      = aws_rds_global_cluster.global_aurora.id
  replication_source_identifier  = aws_rds_cluster.aurora-cluster.arn
  enable_global_write_forwarding = true
  kms_key_id                     = data.aws_kms_key.by_alias_west.arn

  lifecycle {
    create_before_destroy = true
  }

}

# DB subnet group for RDS 
resource "aws_db_subnet_group" "recovery_db_subnet_group" {
  provider   = aws.backup
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.recovery_private_subnet5.id, aws_subnet.recovery_private_subnet6.id]
  tags       = local.recovery_tags
}

resource "aws_rds_cluster_instance" "recovery-aurora-instance" {
  provider           = aws.backup
  identifier         = "recovery-aurora-instance"
  cluster_identifier = aws_rds_cluster.recovery-aurora-cluster.cluster_identifier
  engine             = aws_rds_cluster.recovery-aurora-cluster.engine
  instance_class     = var.db_instance_type
}


# Create event notification for RDS Aurora cluster primary region failover
resource "aws_sns_topic" "cluster_event_topic" {
  name = "aurora-cluster-event-topic"
}

data "aws_iam_policy_document" "event_subscription_policy" {
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
      identifiers = ["events.rds.amazonaws.com"]
    }

    resources = [aws_sns_topic.cluster_event_topic.arn]
  }
}

resource "aws_sns_topic_policy" "event_subscription_policy_attach" {
  arn    = aws_sns_topic.cluster_event_topic.arn
  policy = data.aws_iam_policy_document.event_subscription_policy.json
}

resource "aws_db_event_subscription" "cluster_event_subscription" {
  name      = "aurora-cluster-fail"
  sns_topic = aws_sns_topic.cluster_event_topic.arn

  source_type = "db-cluster"
  source_ids  = [aws_rds_cluster.aurora-cluster.id]

  event_categories = [
    "failover",
    "global-failover",
    "failure",
    "notification",
    "creation",
    "deletion",
    "maintenance"
  ]
  lifecycle {
    replace_triggered_by = [
      aws_rds_cluster.aurora-cluster.id
    ]
  }
}

###################################################
#CloudWatch alarms 

# SNS Topic for Aurora Alarms
resource "aws_sns_topic" "aurora_event_topic" {
  name = "aurora-event-topic"
}

# SNS Topic Subscription for Email Notifications
resource "aws_sns_topic_subscription" "aurora_topic_subscription" {
  topic_arn = aws_sns_topic.aurora_event_topic.arn
  protocol  = "email"
  endpoint  = var.email
}


# Aurora Global DB RPO Lag Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_rpo_lag_alarm" {
  alarm_name          = "AuroraRPOLagHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AuroraGlobalDBRPOLag"
  namespace           = "AWS/RDS"
  period              = 60 # 1 minute intervals
  statistic           = "Average"
  threshold           = 1000 # 1 second RPO lag
  alarm_description   = "Triggered when RPO lag exceeds 1s"
  dimensions = {
    GlobalClusterId = aws_rds_global_cluster.global_aurora.id
  }

  alarm_actions = [
    aws_sns_topic.aurora_event_topic.arn
  ]

  ok_actions = [
    aws_sns_topic.aurora_event_topic.arn
  ]
}


# Event Subscription for RDS Cluster
resource "aws_db_event_subscription" "aurora_event_subscription" {
  name        = "aurora-events"
  sns_topic   = aws_sns_topic.aurora_event_topic.arn
  source_type = "db-cluster"
  source_ids  = [aws_rds_cluster.aurora-cluster.id]
  event_categories = [
    "failover",
    "failure",
    "notification",
    "creation",
    "deletion",
    "maintenance",
    "global-failover"
  ]
}
