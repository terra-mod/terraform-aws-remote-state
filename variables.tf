variable prefix {
  description = "The prefix to use for S3 buckets, since names are globally unique."
  type        = string
}

variable create_user {
  description = "Whether or not to create an IAM User that has permissions to manage the Terraform Remote State."
  type        = bool
  default     = false
}

variable user_name {
  description = "The name of the user generated to manage Terraform Remote State - only applicable if `create_user` is set to true."
  type        = string
  default     = "terraform-remote-state"
}

variable create_user_credentials {
  description = "Whether to generate an AWS IAM Access key for the user - only applicable if `create_user` is set to true."
  type        = bool
  default     = false
}

variable pgp_key {
  description = "An optional PGP Encryption key for the AWS IAM Access key."
  type        = string
  default     = null
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