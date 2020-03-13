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

output role {
  description = "The ARN of the IAM Role that is used to access the Remote State"
  value       = aws_iam_role.role.arn
}