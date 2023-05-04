# CloudFormation Terraform S3 Backend
AWS CloudFormation template to create the S3 and DynamoDB resources needed for a Terraform S3 backend.

## Table of Contents
- [Overview](#overview)
  - [S3](#s3)
  - [DynamoDB](#dynamodb)
  - [Portability](#portability)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Testing](#testing)
- [Validation](#validation)
- [Resources](#resources)

## Overview
This repository contains a CloudFormation template (`tf-s3-backend.yaml`) that creates the S3 and DynamoDB resources needed for a [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3). The S3 bucket provides state storage and the DynamoDB table provides state lock functionality. State lock prevents multiple users/workflows from reading or updating the state file simultaneously. A single backend can host multiple Terraform root modules and workspaces if the backend configuration keys are unique.

A deployment script and Terraform test module are included in this repository, along with a pre-commit configuration, Dependabot configuration, and semantic-release GitHub Actions workflow. Additional information is provided in the [Deployment](#deployment) section of this documentation.

The CloudFormation template appends the AWS account ID to the bucket name and DynamoDB table name by default. Appending the account ID to resource names can be disabled by setting the `AppendAccountID` parameter to `false`. Appending the account ID to the bucket name increases the chance of forming a globally unique bucket name. Appending the account ID to the S3 bucket and DynamoDB table names also identifies the location of the S3 backend when referencing the bucket and table in the Terraform backend configuration.

Cross region replication and access logging may be added as optional features in the future.

### S3
The S3 bucket has versioning enabled, blocks public access, and uses AWS managed KMS encryption by default. A customer managed KMS key can be used by passing a KMS key ARN to the `KMSMasterKeyID` input parameter. An S3 bucket policy is attached to the bucket denying connections that do not use TLS version 1.2 or greater. This prevents transmitting or receiving bucket objects over an insecure network connection.

The default name for the S3 bucket is `terraform-state-<aws-account-id>`. The `terraform-state` prefix can be overridden using the `StateBucketName` input parameter.

### DynamoDB
The DynamoDB table uses the `LockID` partition key specified in the Terraform [DynamoDB State Locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-state-locking) documentation and has server-side encryption enabled by default. The DynamoDB table is configured with `PAY_PER_REQUEST` billing mode to avoid the minimum monthly cost associated with `PROVISIONED` billing mode.

The default name for the DynamoDB table is `terraform-lock-<aws-account-id>`. The `terraform-lock` prefix can be overridden using the `LockTableName` input parameter.

### Portability
The CloudFormation template uses dynamically formed ARNs and does not include hard coded ARN prefixes. Using dynamically formed ARNs allows the template to function properly across AWS partitions, such as AWS GovCloud (US) and the standard AWS partition.

## Prerequisites
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

Install using Homebrew:
```zsh
brew tap hashicorp/tap
brew install \
awscli \
hashicorp/tap/terraform
```
Configure the AWS CLI with credentials capable of creating a CloudFormation stack, S3 bucket, and DynamoDB table. Set the desired AWS region.

## Deployment
To deploy the Terraform S3 backend using CloudFormation, run `./scripts/cfn.sh create-stack`. `cfn.sh` will create a CloudFormation stack called `terraform-backend` using the `tf-s3-backend.yaml` template with default parameter values. `cfn.sh` is designed to aid development and has limited functionality. The script uses generic parameters and a stack level `Name` tag. Customize the script and add additional stack level tags as needed.

Run `./scripts/cfn.sh --help` for a list of available commands. Use the AWS CLI directly to run commands not supported by `cfn.sh`, such as change set and wait commands.

Alternatively, the CloudFormation stack can be deployed via the AWS console or integrated into a CI/CD pipeline. A [stack set](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-concepts.html) can be used for multi-account deployments.

The S3 bucket must be empty (including versioned objects) before deleting the CloudFormation stack.

## Testing
To test the Terraform backend, insert the appropriate backend values into `./test/main.tf`. The values required to configure the Terraform S3 Backend are set as outputs of the CloudFormation stack. If `cfn.sh` was used to deploy the stack, run `./scripts/cfn.sh describe-stacks` to view stack outputs. Stack outputs are also visible in the AWS console or by using the AWS CLI directly.

After modifying `./test/main.tf` with the appropriate Terraform backend values, run `terraform init` from the `./test` directory to initialize the backend. For example:
```console
$ cd ./test
$ terraform init

Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
The `-reconfigure` flag may be necessary if `terraform init` ran previously with a different backend configuration and the `.terraform` directory still includes the old configuration. Or simply delete the outdated test configuration.

Run `terraform apply` and type `yes` to approve the changes. Terraform will write the `current_time` output to the state file. For example:
```console
$ terraform apply

Changes to Outputs:
  + current_time = (known after apply)

You can apply this plan to save these new output values to the Terraform state, without changing any real infrastructure.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes


Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

current_time = "2023-03-01T02:55:35Z"
```

## Validation
Run `aws s3 ls <bucket-name>` to verify the state file exists in the S3 bucket. For example:
```console
$ aws s3 ls <bucket-name>
2023-02-28 21:57:19        273 backend-test.tfstate
```
Run `aws s3 cp s3://<bucket-name>/backend-test.tfstate -` to view the contents of the state file. For example:
```console
$ aws s3 cp s3://<bucket-name>/backend-test.tfstate -
{
  "version": 4,
  "terraform_version": "1.3.9",
  "serial": 1,
  "lineage": "6196a5d3-6fa2-c852-9fe8-cbc1efc911f3",
  "outputs": {
    "current_time": {
      "value": "2023-03-01T17:06:53Z",
      "type": "string"
    }
  },
  "resources": [],
  "check_results": null
}
```
To verify state lock functionality, run `terraform apply` and allow the process hang on the approval step. Run `aws dynamodb scan --table-name <dynamodb-table-name>` from a second terminal session to return the items in the table. The table scan output should include a lock item with the `Info` attribute. The presence of this item indicates that the state is locked and prevents other `terraform` processes from updating the state file.

Terraform will delete the lock item containing the `Info` attribute to unlock the state when the `terraform` process that created it completes. After the initial state file creation, Terraform will also maintain a persistent item with an md5 hash digest of the state file. The DynamoDB table scan output should be similar to the following:
```console
$ aws dynamodb scan --table-name <dynamodb-table-name>
{
    "Items": [
        {
            "LockID": {
                "S": "<bucket-name>/backend-test.tfstate"
            },
            "Info": {
                "S": "{\"ID\":\"8ed32e61-d3b0-45f6-8e54-4874151d1421\",\"Operation\":\"OperationTypeApply\",\"Info\":\"\",\"Who\":\"<username>@<hostname>\",\"Version\":\"1.3.9\",\"Created\":\"2023-03-01T03:43:55.862597Z\",\"Path\":\"<bucket-name>/backend-test.tfstate\"}"
            }
        },
        {
            "Digest": {
                "S": "b72fe49326d8f111c94566d53c2ef176"
            },
            "LockID": {
                "S": "<bucket-name>/backend-test.tfstate-md5"
            }
        }
    ],
    "Count": 2,
    "ScannedCount": 2,
    "ConsumedCapacity": null
}
```
Another method of verifying state lock is to run `terraform plan` or `apply` from a second terminal session while the first `terraform apply` is pending approval. Or have a second user run `terraform plan` or `apply`. When trying to run a `plan` or `apply` on a backend that is locked, Terraform will produce the following error message:
```shell
$ terraform apply
╷
│ Error: Error acquiring the state lock
│
│ Error message: ConditionalCheckFailedException: The conditional request failed
│ Lock Info:
│   ID:        8ed32e61-d3b0-45f6-8e54-4874151d1421
│   Path:      <bucket-name>/backend-test.tfstate
│   Operation: OperationTypeApply
│   Who:       <username>@<hostname>
│   Version:   1.3.9
│   Created:   2023-03-01 03:43:55.862597 +0000 UTC
│   Info:
│
│
│ Terraform acquires a state lock to protect the state from being written
│ by multiple users at the same time. Please resolve the issue above and try
│ again. For most commands, you can disable locking with the "-lock=false"
│ flag, but this is not recommended.
```

## Resources
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS CLI CloudFormaton](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/index.html)
- [S3 Bucket Naming Rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)
- [DynamoDB Naming Rules](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html)
