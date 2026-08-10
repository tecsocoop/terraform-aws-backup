# terraform-aws-backup

Terraform module to standardize AWS Backup: creates a locked backup vault, the
IAM role for AWS Backup, a backup plan with parametrizable rules, a tag-based
selection with exclusion conditions, and SNS notifications (with an email
subscription).

## Requirements

| Name      | Version   |
|-----------|-----------|
| terraform | >= 1.3.7  |
| aws       | >= 5.9.0  |

## Usage

Published on the [public Terraform Registry](https://registry.terraform.io/)
under the `tecsocoop` namespace:

```hcl
module "backup" {
  source  = "tecsocoop/backup/aws"
#  version = "X.X.X" # see the latest available tag

  name  = "prd-tecso"
  email = "alerts@example.com"

  # Required: no default. Each entry is a `rule` block of the backup plan.
  backup_rules = [
    {
      rule_name                = "daily"
      schedule                 = "cron(30 3 ? * 2,3,4,5,6,7 *)"
      start_window             = 60
      enable_continuous_backup = true
      delete_after             = 1
    },
    {
      rule_name                = "weekly"
      schedule                 = "cron(30 3 ? * 1 *)"
      start_window             = 60
      enable_continuous_backup = false
      delete_after             = 7
    },
    {
      rule_name                = "monthly"
      schedule                 = "cron(0 4 1 * ? *)"
      start_window             = 60
      enable_continuous_backup = false
      delete_after             = 60
    },
  ]

  # Tag conditions that EXCLUDE resources from the backup selection.
  backup_exclusion_conditions = [
    { tag = "AWS_Backups", value = "false", operator = "string_not_equals" },
    { tag = "Environment", value = "sit", operator = "string_not_like" },
    { tag = "Environment", value = "uat", operator = "string_not_like" },
    { tag = "Environment", value = "pre", operator = "string_not_like" },
    { tag = "Environment", value = "dev", operator = "string_not_like" },
  ]
}
```

## Exclusion conditions (`string_not_equals` vs `string_not_like`)

A resource is included in the backup selection when it matches every condition.
The defaults **exclude** anything tagged `AWS_Backups = false` and any resource
whose `Environment` tag is `sit`, `uat`, `pre` or `dev`.

Choose the operator per entry:

- `string_not_equals` / `string_equals`: exact match, **no wildcards**. Use this
  for exact values (the clearer, recommended default).
- `string_not_like` / `string_like`: supports wildcards (`*`, `?`). Use only when
  the value needs a pattern, e.g. `dev-*`.

Modeled as a **list** (not a map) because the same tag can appear multiple times
(e.g. `Environment`).

```hcl
backup_exclusion_conditions = [
  { tag = "AWS_Backups", value = "false" },              # operator defaults to string_not_equals
  { tag = "Environment", value = "dev-*", operator = "string_not_like" },
]
```

Refs:
- [`aws_backup_selection` condition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection)
- [AWS Backup `Condition` API](https://docs.aws.amazon.com/aws-backup/latest/devguide/API_Condition.html)

## Notifications

`backup_vault_events` defaults to the current value (`BACKUP_JOB_FAILED`) and
accepts any supported event (validated by the module). The email subscription
must be **confirmed by the recipient** (check the inbox).

Ref: [AWS Backup vault events](https://docs.aws.amazon.com/aws-backup/latest/devguide/API_BackupVaultEvent.html)

<details>
<summary>Variables</summary>

| Variable                        | Descripción                                                            | Valores                                                                 | Default                                   |
|---------------------------------|------------------------------------------------------------------------|-------------------------------------------------------------------------|-------------------------------------------|
| `name`                          | Base name for the created resources (suffixes appended).               | string - e.g. `prd-tecso`                                               | -                                         |
| `email`                         | Email subscribed to the SNS notifications topic.                       | string - e.g. `alerts@example.com`                                      | -                                         |
| `backup_rules`                  | Backup plan rules (**required**, no default).                          | `list(object({ rule_name, schedule, start_window?, completion_window?, enable_continuous_backup?, delete_after, cold_storage_after? }))` | -                                         |
| `backup_exclusion_conditions`   | Tag conditions that exclude resources from the selection.              | `list(object({ tag, value, operator? }))`                               | `AWS_Backups=false` + `Environment` sit/uat/pre/dev |
| `backup_vault_events`           | Events published to SNS.                                               | `list(string)`                                                          | `["BACKUP_JOB_FAILED"]`                   |
| `selected_resources`            | Resource ARNs assigned to the selection.                              | `list(string)`                                                          | `["*"]`                                   |
| `vault_lock_min_retention_days` | Minimum retention for the vault lock.                                  | number                                                                  | `1`                                       |
| `vault_lock_max_retention_days` | Maximum retention for the vault lock.                                  | number                                                                  | `65`                                      |
| `enable_s3_backup_policy`       | Attach the S3 backup managed policy to the IAM role.                   | bool                                                                    | `true`                                    |
| `tags`                          | Common tags applied to all resources.                                  | `map(string)`                                                           | `{}`                                      |

</details>

<details>
<summary>Outputs</summary>

| Output          | Description                                        |
|-----------------|----------------------------------------------------|
| `vault_id`      | ID (name) of the backup vault.                     |
| `vault_arn`     | ARN of the backup vault.                           |
| `iam_role_arn`  | ARN of the IAM role assumed by AWS Backup.         |
| `iam_role_name` | Name of the IAM role assumed by AWS Backup.        |
| `plan_id`       | ID of the backup plan.                             |
| `plan_arn`      | ARN of the backup plan.                            |
| `selection_id`  | ID of the backup selection.                        |
| `sns_topic_arn` | ARN of the SNS notifications topic.                |

</details>

## License

Licensed under the [Apache License 2.0](LICENSE).
