// Requires Terraform 0.12 or higher
terraform {
  required_version = "~> 0.12"
}

locals {
  state_name = "${var.prefix}-tf-remote-state"
  name_tag   = "Terraform Remote State"

  tags = merge(var.tags, {
    ManagedBy = "terraform"
  })
}

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
  region = var.region
  acl    = "log-delivery-write"
}

/**
 * Create an S3 Bucket for the state that is encrypted, has logging, and is versioned.
 */
resource aws_s3_bucket state {
  bucket = local.state_name
  region = var.region
  acl    = "private"

  depends_on = [aws_kms_key.key]

  logging {
    target_bucket = aws_s3_bucket.logging.id
    target_prefix = "logs/"
  }

  server_side_encryption_configuration {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.key.key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning {
    enabled = true
  }

  // Throw an error if we try to delete this resource
  lifecycle {
    prevent_destroy = true
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

  // Throw an error if we try to delete this resource
  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

/**
 * Create an IAM Role for managing Terraform Remote State.
 */
resource aws_iam_role role {
  path = "/terraform-remote-state/"

  name = "tf-state-management"
  description = "Terraform Remote State Management"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowedPrincipals",
        Action = "sts:AssumeRole",
        Principal = {
          AWS = var.assume_role_principals
        },
        Effect = "Allow"
      }
    ]
  })
}

/**
 * Create an IAM Policy allows management of the Terraform Remote State.
 */
resource aws_iam_role_policy policy {
  role = aws_iam_role.role.id

  name        = "tf-state-management-policy"
  description = "Terraform Remote State Management"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "S3GetObject",
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.state.bucket}/*"
      },
      {
        Sid      = "S3ListBucket",
        Effect   = "Allow",
        Action   = "s3:ListBucket",
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
        Sid      = "S3GetObject",
        Effect   = "Allow",
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