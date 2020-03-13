variable prefix {
  description = "A prefix to use for S3 buckets, since names are globally unique."
  type        = string
}

variable region {
  description = "The AWS Region that the resources should be deployed into."
  type        = string
  default     = "us-east-1"
}

variable assume_role_principals {
  description = "A set of principals that are allowed to assume the role for managing Terraform State."
  type        = set(string)
  default     = []
}

variable tags {
  description = "Any additional tags that should be added to taggable resources created by this module."
  type        = map(string)
  default     = {}
}