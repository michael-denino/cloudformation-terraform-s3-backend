# Terraform S3 Backed Test
This Terraform module provides the minimum configuration necessary to test an S3 backend. A `current_time` output is updated every time `terraform apply` is executed. This module configuration facilitates the testing and validation of state storage and state locking functionality in a Terraform S3 backend. This module does not create resources.

To utilize this test module, update the backend configuration in `main.tf` with an S3 bucket name, DynamoDB table name, and the AWS region where the backend is deployed. Run `terraform init` and `terraform apply` to test the backend. Refer to the README in the root of this repository for more information.

## Terraform Docs
The following documentation was automatically generated using `terraform-docs`.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_current_time"></a> [current\_time](#output\_current\_time) | Timestamp represented in RFC 3339 date and time format. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
