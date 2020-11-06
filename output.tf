output bucket {
  description = "The name of the S3 Bucket used for Terraform Remote State."
  value       = aws_s3_bucket.state.bucket
}

output region {
  description = "The AWS Region the Terraform Remote State resources are in."
  value       = aws_s3_bucket.state.region
}

output dynamodb {
  description = "The DynamoDB Table used for locking the Remote State."
  value       = aws_dynamodb_table.table.name
}

output user {
  description = "The name of the User generated to manage the Remote State."
  value       = var.create_user ? aws_iam_user.user[0].name : null
}

output credentials {
  description = "The IAM Access Key and Secret of the user, if it was opted to generate the credentials."
  sensitive   = true
  value       = var.create_user_credentials ? {
    access_key = aws_iam_access_key.key[0].id
    secret = var.pgp_key != null && var.pgp_key != "" ? aws_iam_access_key.key[0].encrypted_secret : aws_iam_access_key.key[0].secret
  } : null
}

output role {
  description = "The ARN of the IAM Role that is used to access the Remote State"
  value       = aws_iam_role.role.arn
}

output example_backend_configuration {
  description = "Provides an example of what the `backend` configuration would look like in order to use the provisioned Remote State"
  value = <<BACKEND

terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "${aws_s3_bucket.state.bucket}"
    dynamodb_table = "${aws_dynamodb_table.table.name}"
    role_arn       = "${aws_iam_role.role.arn}"
    key            = "{some-project-name}" // must be unique across projects
  }
}
BACKEND
}