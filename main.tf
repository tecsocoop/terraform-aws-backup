locals {
  vault_name = "${var.name}-bkp"
  role_name  = "${var.name}-backup"
  sns_name   = "${var.name}-bkp"

  # Group exclusion conditions by operator so each maps to its own dynamic block.
  string_equals     = [for c in var.backup_exclusion_conditions : c if c.operator == "string_equals"]
  string_not_equals = [for c in var.backup_exclusion_conditions : c if c.operator == "string_not_equals"]
  string_like       = [for c in var.backup_exclusion_conditions : c if c.operator == "string_like"]
  string_not_like   = [for c in var.backup_exclusion_conditions : c if c.operator == "string_not_like"]
}

###############
#### VAULT ####
###############

resource "aws_backup_vault" "bkp" {
  name = local.vault_name
  #kms_key_arn = aws_kms_key.example.arn # use default kms key aws/backup

  tags = var.tags
}

resource "aws_backup_vault_lock_configuration" "locker" {
  backup_vault_name  = aws_backup_vault.bkp.name
  max_retention_days = var.vault_lock_max_retention_days
  min_retention_days = var.vault_lock_min_retention_days
}

#############
#### IAM ####
#############

data "aws_iam_policy_document" "bkp" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "bkp" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.bkp.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "bkp" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.bkp.name
}

resource "aws_iam_role_policy_attachment" "bkp_s3" {
  count      = var.enable_s3_backup_policy ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
  role       = aws_iam_role.bkp.name
}

######################
#### Backup Plans ####
######################

resource "aws_backup_plan" "bkp" {
  name = "${var.name}-bkp"

  dynamic "rule" {
    for_each = var.backup_rules
    content {
      rule_name                = rule.value.rule_name
      target_vault_name        = aws_backup_vault.bkp.name
      schedule                 = rule.value.schedule
      start_window             = rule.value.start_window
      completion_window        = rule.value.completion_window
      enable_continuous_backup = rule.value.enable_continuous_backup

      lifecycle {
        delete_after       = rule.value.delete_after
        cold_storage_after = rule.value.cold_storage_after
      }
    }
  }

  tags = var.tags
}

###########################
#### Backup Selections ####
###########################

resource "aws_backup_selection" "bkp" {
  iam_role_arn = aws_iam_role.bkp.arn
  name         = "selection_AWS_Backup"
  plan_id      = aws_backup_plan.bkp.id

  resources = var.selected_resources

  condition {
    dynamic "string_equals" {
      for_each = local.string_equals
      content {
        key   = "aws:ResourceTag/${string_equals.value.tag}"
        value = string_equals.value.value
      }
    }

    dynamic "string_not_equals" {
      for_each = local.string_not_equals
      content {
        key   = "aws:ResourceTag/${string_not_equals.value.tag}"
        value = string_not_equals.value.value
      }
    }

    dynamic "string_like" {
      for_each = local.string_like
      content {
        key   = "aws:ResourceTag/${string_like.value.tag}"
        value = string_like.value.value
      }
    }

    dynamic "string_not_like" {
      for_each = local.string_not_like
      content {
        key   = "aws:ResourceTag/${string_not_like.value.tag}"
        value = string_not_like.value.value
      }
    }
  }
}

##################################
#### Backup SNS Notifications ####
##################################
# The SNS subscription must be confirmed by the recipient (check the inbox).

resource "aws_sns_topic" "bkp" {
  name = local.sns_name

  tags = var.tags
}

data "aws_iam_policy_document" "bkp_sns" {
  policy_id = "__default_policy_ID"
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
      aws_sns_topic.bkp.arn,
    ]
    sid = "__default_statement_ID"
  }
}

resource "aws_sns_topic_policy" "bkp" {
  arn    = aws_sns_topic.bkp.arn
  policy = data.aws_iam_policy_document.bkp_sns.json
}

resource "aws_backup_vault_notifications" "bkp" {
  backup_vault_name   = aws_backup_vault.bkp.name
  sns_topic_arn       = aws_sns_topic.bkp.arn
  backup_vault_events = var.backup_vault_events
}

resource "aws_sns_topic_subscription" "bkp_alerts" {
  topic_arn = aws_sns_topic.bkp.arn
  protocol  = "email"
  endpoint  = var.email

  lifecycle {
    ignore_changes = [
      confirmation_timeout_in_minutes,
      endpoint_auto_confirms,
    ]
  }
}
