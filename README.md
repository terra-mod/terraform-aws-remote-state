# Terraform Remote State - Using S3 & DynamoDB

This module creates the necessary resources to provide Remote Backend for Terraform which supports Workspaces and Locking.

Since there is an obvious circular dependency here, this should, ideally, be the only Terraform configuration that is
relying on Local state.

Read more about [Remote State](https://www.terraform.io/docs/state/remote.html) and the 
[S3 Backend](https://www.terraform.io/docs/backends/types/s3.html) in the Terraform documentation.