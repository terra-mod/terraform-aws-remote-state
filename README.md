# Terraform Remote State - AWS S3 & DynamoDB

Creates the necessary resources used to support the Terraform AWS Backend.

#### Why AWS (S3 & DynamoDB)
The S3 backend is one of the most common ways to store Remote State in Terraform. The combination of S3 for storage
and DynamoDB for locking and consistency adds a lot of safeguards over local state and basic HTTPS backends.

   - Full [Workspace](https://www.terraform.io/docs/state/workspaces.html) (named states) support
   - [State Locking](https://www.terraform.io/docs/state/locking.html) & Consistency Checks via DynamoDB
   - [Versioning](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/enable-versioning.html) of the S3 bucket can be used for state recovery
   - Allows for [Logging](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/server-access-logging.html) of all State changes

### How To Use
In your Terraform projects, specify the the `backend` block inside the top level `terraform` object. The following
properties need to be specified and an example can be retrieved from the output (`terraform output`) from this project.

**Note** - The `key` attribute needs to be a unique value across projects.

   - `encrypt` - (Required) Set this to `true`. We absolutely want server side encryption.
   - `region` - (Required) The region the backend resources exist in.
   - `bucket` - (Required) The name of the S3 bucket.
   - `dynamodb_table` - (Required) The name of the DynamoDB Table.
   - `key` - (Required) The path to the state file inside the bucket.

###### Example

     terraform {
       backend "s3" {
         encrypt        = "true"
         region         = "us-west-2"
         bucket         = "my-tf-remote-state"
         dynamodb_table = "my-tf-remote-state"
         key            = "{some-project-name}"
       }
     }

### Managing the State from this Terraform Project

There is an obvious circular dependency if you're looking to use the resultant Backend created by this module to
manage its own state. It can be done, but this may be one of the few Terraform projects that you keep in Local state
and commit to your VCS.

**Warning**: This module can optionally generate IAM Access Key with access to your Remote State - if optional PGP 
Encryption is not used, you may have plaintext AWS Credentials in your Statefile. The local state for this module should 
never be committed to a public repository.

##### Moving the local state to use the generated backend
Its required to first generate the resources using local state - then migrate to the newly created Backend.

   1. Terraform Init
   1. Terraform Apply - without a Backend specified
   2. Configure the [Backend](https://www.terraform.io/docs/backends/) block using the output of this Terraform configuration
   3. Terraform Init - Re-initializing Terraform will detect the Backend change and configure the Backend
   4. When prompted allow the existing State to be migrated

##### Making changes to these Remote State resources
After migrating to the Remote state, management of the Terraform state will be using the backend that this repo manages - so there are
a few caveats. The S3 Bucket and DynamoDB table are not [prevented from being destroyed](https://www.terraform.io/docs/configuration/resources.html#prevent_destroy).
However, this module does not use `force_destroy` on the S3 Bucket, which means it will fail to be destroyed if its not first empty.
This was intentionally kept this way to help avoid any accidental destroy plan, or a change that would replace the bucket
from deleting existing managed state.

It's very important that changes made to the Remote State are peer reviewed and handled carefully to avoid impacting
the Remote State of any other projects. Once configured, make changes cautiously.