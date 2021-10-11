// Requires Terraform 0.12 or higher
terraform {
  required_version = ">= 0.12"
}

locals {
  state_name = "${var.prefix}-tf-remote-state"
  name_tag   = "Terraform Remote State"

  tags = merge(var.tags, {
    ManagedBy = "terraform"
  })
  
  principals = distinct(concat([data.aws_caller_identity.self.account_id], tolist(var.assume_role_principals)))

  iam_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "S3Access",
        Effect = "Allow",
        Action = ["s3:*"],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.state.bucket}/*"
        ]
      },
      {
        Sid      = "S3ListBucket",
        Effect   = "Allow",
        Action   = "s3:*",
        Resource = "arn:aws:s3:::${aws_s3_bucket.state.bucket}"
      },
      {
        Sid      = "KMSListKeys",
        Effect   = "Allow",
        Action   = "kms:ListKeys",
        Resource = "*"
      },
      {
        Sid    = "KMSRead",
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.key.arn
      },
      {
        Sid    = "DynamoDBAccess",
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.table.arn
      }
    ]
  })
}

/**
 * Look up the current account.
 */
data aws_caller_identity self {}

/**
 * Create a new KMS Key used for encrypting the Remote State bucket.
 */
resource aws_kms_key key {
  description = "Encryption key for Terraform Remote State"

  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}

/**
 * Create the Alias for the KMS Key
 */
resource aws_kms_alias alias {
  name          = "alias/${local.state_name}"
  target_key_id = aws_kms_key.key.key_id
}

/**
 * Create an S3 Bucket that can be used for logging access to the Remote State bucket.
 */
resource aws_s3_bucket logging {
  bucket = "${var.prefix}-tf-state-logs"
  acl    = "log-delivery-write"
}

/**
 * Create an S3 Bucket for the state that is encrypted, has logging, and is versioned.
 */
resource aws_s3_bucket state {
  bucket = local.state_name
  acl    = "private"

  depends_on = [aws_kms_key.key]

  logging {
    target_bucket = aws_s3_bucket.logging.id
    target_prefix = "logs/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.key.key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning {
    enabled = true
  }

  tags = local.tags
}

/**
 * Create a DynamoDB Table that will be used for locking access to the Remote State.
 */
resource aws_dynamodb_table table {
  name = local.state_name

  server_side_encryption {
    enabled = true
  }

  hash_key       = "LockID"
  read_capacity  = 5
  write_capacity = 1

  attribute {
    type = "S"
    name = "LockID"
  }

  tags = local.tags
}

/**
 * Optional - Create an IAM User for managing Terraform Remote State.
 *
 * While using Roles and delegation through AssumeRole seems ideal, it may be preferred
 * to create a Single user with credentials that is shared across AWS Account and Terraform Projects.
 */
resource aws_iam_user user {
  count = var.create_user ? 1 : 0

  name = var.user_name
}

/**
 * Attach the management policy to the User if it's being created.
 */
resource aws_iam_user_policy user_policy {
  count = var.create_user ? 1 : 0

  name   = "tf-state-management"
  user   = aws_iam_user.user[0].name
  policy = local.iam_policy
}

/**
 * Optional - Create IAM Credentials for the User.
 *
 * It may be preferred to manage the Access Key manually to avoid it being stored in state.
 */
resource aws_iam_access_key key {
  count = var.create_user && var.create_user_credentials ? 1 : 0

  user    = aws_iam_user.user[0].name
  pgp_key = var.pgp_key == null || var.pgp_key == "" ? null : var.pgp_key
}

/**
 * Create an IAM Role for managing Terraform Remote State.
 */
resource aws_iam_role role {
  path = "/terraform-remote-state/"

  name        = "tf-state-management"
  description = "Terraform Remote State Management"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowEC2",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Sid    = "AllowPrincipals",
        Effect = "Allow"
        Principal = {
          # If no principals were given then allow within the same account
          AWS = local.principals
        },
        Action = "sts:AssumeRole",
      }
    ]
  })
}

/**
 * Create an IAM Policy allows management of the Terraform Remote State.
 */
resource aws_iam_role_policy role_policy {
  role = aws_iam_role.role.id

  name = "tf-state-management-policy"

  policy = local.iam_policy
}
