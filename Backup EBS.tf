# Create backup vaults in Primary and Recovery Region


resource "aws_backup_vault" "backup_vault" {
  name = var.backup_vault
  #kms_key_id         = data.aws_kms_key.by_alias_east.arn
}
resource "aws_backup_vault" "backup_vault2" {
  name     = var.backup_vault2
  provider = aws.backup
  #kms_key_id         = data.aws_kms_key.by_alias_west.arn
}

# Create backup plan for EBS volumes & Aurora EBS

resource "aws_backup_plan" "consolidated_backup_plan" {
  name = "consolidated_backup_plan"

  # Daily backup rule

  rule {
    rule_name         = "daily_backup_rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 12 * * ? *)"
    lifecycle {
      delete_after = 7
    }
    copy_action {
      destination_vault_arn = aws_backup_vault.backup_vault2.arn
      lifecycle {
        delete_after = 15
      }
    }
  }
  # Weekly Backups (Tuesdays)

  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 12 ? * 2 *)" # Weekly on Tuesdays at 12 PM UTC
    lifecycle {
      cold_storage_after = 30 # Keep in warm storage for 30 days
      delete_after       = 120
    }
    copy_action {
      destination_vault_arn = aws_backup_vault.backup_vault2.arn
      lifecycle {
        cold_storage_after = 30 # Keep in warm storage for 30 days
        delete_after       = 120
      }
    }
  }

  # Monthly Backups (Tuesdays closest to 1st of each month)

  rule {
    rule_name         = "monthly-backup"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 12 ? * 2#1 *)" # Monthly on the 1st Tuesday at 12 PM UTC
    lifecycle {
      cold_storage_after                        = 15
      opt_in_to_archive_for_supported_resources = true
      delete_after                              = 365
    }
    copy_action {
      destination_vault_arn = aws_backup_vault.backup_vault2.arn
      lifecycle {
        cold_storage_after                        = 365 # Keep in warm storage for 1 year
        opt_in_to_archive_for_supported_resources = true
        delete_after                              = 1095 # Keep for 3 years
      }
    }
  }

}

resource "aws_backup_selection" "consolidated_backup_plan" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "tf_consolidated_backup_selection"
  plan_id      = aws_backup_plan.consolidated_backup_plan.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = "production"
  }

}
# Create an IAM role with the default managed IAM Policy for allowing AWS Backup to create backups
data "aws_iam_policy_document" "assume_role_backup" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "backup" {
  name               = "backup_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_backup.json
}
resource "aws_iam_role_policy_attachment" "backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}
resource "aws_iam_role_policy_attachment" "restore_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}

# Create the restore plan for the primary region EBS

resource "aws_backup_restore_testing_plan" "ebs_primary" {
  name = "restore_ebs_primary"
  recovery_point_selection {
    algorithm            = "RANDOM_WITHIN_WINDOW"
    include_vaults       = [aws_backup_vault.backup_vault.arn]
    recovery_point_types = ["SNAPSHOT"]
  }
  schedule_expression = "cron(0 0 ? * 1#1 *" # Monthly on the first Monday
}

# Resource Selection for Restore Testing - primary - EBS

resource "aws_backup_restore_testing_selection" "ebs_primary" {
  name                      = "ebs_selection_primary"
  restore_testing_plan_name = aws_backup_restore_testing_plan.ebs_primary.name
  protected_resource_type   = "EBS"
  iam_role_arn              = aws_iam_role.backup.arn
  protected_resource_conditions {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = "production"
    }
  }
}

# Create the restore plan for the secondary region 

resource "aws_backup_restore_testing_plan" "ebs_secondary" {
  name     = "restore_ebs_secondary"
  provider = aws.backup
  recovery_point_selection {
    algorithm            = "RANDOM_WITHIN_WINDOW"
    include_vaults       = [aws_backup_vault.backup_vault2.arn]
    recovery_point_types = ["SNAPSHOT"]
  }
  schedule_expression = "cron(0 0 ? * 1#1 *)" # Monthly on the first Monday
}

# Resource Selection for Restore Testing - secondary

resource "aws_backup_restore_testing_selection" "ebs_secondary" {
  name                      = "ebs_selection2"
  provider                  = aws.backup
  restore_testing_plan_name = aws_backup_restore_testing_plan.ebs_secondary.name
  protected_resource_type   = "EBS"
  iam_role_arn              = aws_iam_role.backup.arn
  protected_resource_conditions {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = "production"
    }
  }
}


# Create SNS topic for primary region


resource "aws_sns_topic" "backup_events" {
  name = "backup-vault-events"
}
data "aws_iam_policy_document" "test" {
  policy_id = "AllowSNSPublish"
  statement {
    actions = [
      "SNS:Publish",
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    resources = [
      aws_sns_topic.backup_events.arn,
    ]

    sid = "__default_statement_ID"
  }
}
resource "aws_sns_topic_policy" "test" {
  arn    = aws_sns_topic.backup_events.arn
  policy = data.aws_iam_policy_document.test.json
}
resource "aws_backup_vault_notifications" "primary" {
  backup_vault_name   = aws_backup_vault.backup_vault.name
  sns_topic_arn       = aws_sns_topic.backup_events.arn
  backup_vault_events = ["BACKUP_JOB_COMPLETED", "RESTORE_JOB_COMPLETED", "BACKUP_JOB_FAILED", "RESTORE_JOB_FAILED"]
}
resource "aws_sns_topic_subscription" "backup_events" {
  topic_arn = aws_sns_topic.backup_events.arn
  protocol  = "email"
  endpoint  = var.email
}