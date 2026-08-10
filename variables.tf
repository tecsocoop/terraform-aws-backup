##########################
######## Required ########
##########################

variable "name" {
  description = "Base name for the created resources, e.g. prd-tecso. Suffixes are appended (-bkp, -backup)."
  type        = string
}

variable "email" {
  description = "Email address subscribed to the SNS topic that receives backup notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.email))
    error_message = "email must be a valid email address, e.g. alerts@example.com."
  }
}

variable "backup_rules" {
  description = <<-EOT
    Backup plan rules. Required (no default). Each rule maps to a `rule` block of
    aws_backup_plan. `delete_after` is the lifecycle retention (days).
  EOT
  type = list(object({
    rule_name                = string
    schedule                 = string
    start_window             = optional(number, 60)
    completion_window        = optional(number)
    enable_continuous_backup = optional(bool, false)
    delete_after             = number
    cold_storage_after       = optional(number)
  }))

  validation {
    condition     = length(var.backup_rules) > 0
    error_message = "backup_rules must contain at least one rule."
  }
}

##########################
######## Optional ########
##########################

variable "backup_exclusion_conditions" {
  description = <<-EOT
    Conditions that EXCLUDE resources from the backup selection (tag = value not
    backed up). Modeled as a list (not a map) because the same tag can appear
    multiple times (e.g. Environment). `operator` is one of: string_not_equals,
    string_not_like, string_equals, string_like. Use string_not_equals for exact
    values; string_not_like only when the value needs wildcards (*, ?).
  EOT
  type = list(object({
    tag      = string
    value    = string
    operator = optional(string, "string_not_equals")
  }))
  default = [
    { tag = "AWS_Backups", value = "false", operator = "string_not_equals" },
    { tag = "Environment", value = "sit", operator = "string_not_like" },
    { tag = "Environment", value = "uat", operator = "string_not_like" },
    { tag = "Environment", value = "pre", operator = "string_not_like" },
    { tag = "Environment", value = "dev", operator = "string_not_like" },
  ]

  validation {
    condition = alltrue([
      for c in var.backup_exclusion_conditions :
      contains(["string_equals", "string_not_equals", "string_like", "string_not_like"], c.operator)
    ])
    error_message = "operator must be one of: string_equals, string_not_equals, string_like, string_not_like."
  }
}

variable "backup_vault_events" {
  description = <<-EOT
    Events published to the SNS topic via aws_backup_vault_notifications. Defaults
    to the current value (BACKUP_JOB_FAILED). Add any other supported events.
  EOT
  type        = list(string)
  default     = ["BACKUP_JOB_FAILED"]

  validation {
    condition = alltrue([
      for e in var.backup_vault_events : contains([
        "BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "BACKUP_JOB_SUCCESSFUL",
        "BACKUP_JOB_FAILED", "BACKUP_JOB_EXPIRED",
        "RESTORE_JOB_STARTED", "RESTORE_JOB_COMPLETED", "RESTORE_JOB_SUCCESSFUL",
        "RESTORE_JOB_FAILED",
        "COPY_JOB_STARTED", "COPY_JOB_SUCCESSFUL", "COPY_JOB_FAILED",
        "RECOVERY_POINT_MODIFIED",
        "BACKUP_PLAN_CREATED", "BACKUP_PLAN_MODIFIED",
        "S3_BACKUP_OBJECT_FAILED", "S3_RESTORE_OBJECT_FAILED",
      ], e)
    ])
    error_message = "Each event must be a valid AWS Backup vault event. See https://docs.aws.amazon.com/aws-backup/latest/devguide/API_BackupVaultEvent.html"
  }
}

variable "selected_resources" {
  description = "Resource ARNs assigned to the backup selection. Default '*' (all supported resources in the account/region)."
  type        = list(string)
  default     = ["*"]
}

variable "vault_lock_min_retention_days" {
  description = "Minimum retention (days) for aws_backup_vault_lock_configuration."
  type        = number
  default     = 1
}

variable "vault_lock_max_retention_days" {
  description = "Maximum retention (days) for aws_backup_vault_lock_configuration."
  type        = number
  default     = 65
}

variable "enable_s3_backup_policy" {
  description = "Attach AWSBackupServiceRolePolicyForS3Backup to the backup IAM role (required to back up S3)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources created by the module."
  type        = map(string)
  default     = {}
}
