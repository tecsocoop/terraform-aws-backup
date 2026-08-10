###############
######## Vault
###############

output "vault_id" {
  description = "ID (name) of the backup vault"
  value       = aws_backup_vault.bkp.id
}

output "vault_arn" {
  description = "ARN of the backup vault"
  value       = aws_backup_vault.bkp.arn
}

###############
######## IAM
###############

output "iam_role_arn" {
  description = "ARN of the IAM role assumed by AWS Backup"
  value       = aws_iam_role.bkp.arn
}

output "iam_role_name" {
  description = "Name of the IAM role assumed by AWS Backup"
  value       = aws_iam_role.bkp.name
}

###############
######## Plan
###############

output "plan_id" {
  description = "ID of the backup plan"
  value       = aws_backup_plan.bkp.id
}

output "plan_arn" {
  description = "ARN of the backup plan"
  value       = aws_backup_plan.bkp.arn
}

output "selection_id" {
  description = "ID of the backup selection"
  value       = aws_backup_selection.bkp.id
}

###############
######## SNS
###############

output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives backup notifications"
  value       = aws_sns_topic.bkp.arn
}
