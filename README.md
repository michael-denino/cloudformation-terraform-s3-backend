# CloudFormation Terraform S3 Backend
AWS CloudFormation template to create the S3 and DynamoDB resources needed for a Terraform S3 backend.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Testing](#testing)
- [Validation](#validation)
- [Resources](#resources)

## Prerequisites
```zsh
brew install \
awscli
terraform
```
Configure the AWS CLI with credentials capable of creating a CloudFormation stack, S3 bucket, and DynamoDB table. Set the desired AWS region.

## Deployment
To deploy the Terraform S3 backend using CloudFormation, run `./scripts/cfn.sh create-stack`. `.cfn.sh` will create a CloudFormation stack called `terraform-backend` using the `tf-s3-backend.yaml` template with default parameter values. `.cfn.sh` is designed to aid development and has limited functionality. The script uses generic parameters and a stack level `Name` tag. The `tf-s3-backend.yaml` CloudFormation template appends the AWS account number when forming the S3 bucket and DynamoDB table names. Customize the script and add additional stack level tags as needed.

Run `./scripts/cfn.sh --help` for a list of available commands. Use the AWS CLI directly to run commands not supported by `.cfn.sh`, such as change set and wait commands.

Alternatively, the CloudFormation stack can be deployed via the AWS console or integrated into a CI/CD pipeline. A stack set can be used for multi-account deployments.

The S3 bucket must be empty (including versioned objects) before deleting the CloudFormation stack.

## Testing
To test the Terraform backend, insert the appropriate backend values into `./test/main.tf`. The values required to configure the Terraform S3 Backend are set as outputs of the CloudFormation stack. After adding the appropriate backend values, run `terraform init` from the `./test` directory to initialize the backend. For example:
```zsh
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
```zsh
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
```zsh
$ aws s3 ls <bucket-name>
2023-02-28 21:57:19        273 backend-test.tfstate
```
Run `aws s3 cp s3://<bucket-name>/backend-test.tfstate -` to view the contents of the state file. For example:
```zsh
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
To verify state lock funtionality, run `terraform apply` and allow the process hang on the approval step. Run `aws dynamodb scan --table-name <dynamodb-table-name>` from a second terminal session to return the items in the table. The table scan output should include a lock item with the `Info` attribute. The presence of this item indicates that the state is locked and prevents other `terraform` processes from updating the state file.

Terraform will delete the lock item containing the `Info` attribute to unlock the state when the `terraform` process that created it completes. After the initial state file creation, Terraform will also maintain a persistent item with an md5 hash digest of the state file. The DynamoDB table scan output should be similar to the following:
```zsh
$ aws dynamodb scan --table-name <dynamodb-table-name>
{
    "Items": [
        {
            "LockID": {
                "S": "terraform-state-982542462374/backend-test.tfstate"
            },
            "Info": {
                "S": "{\"ID\":\"8ed32e61-d3b0-45f6-8e54-4874151d1421\",\"Operation\":\"OperationTypeApply\",\"Info\":\"\",\"Who\":\"<username>@<hostname>\",\"Version\":\"1.3.9\",\"Created\":\"2023-03-01T03:43:55.862597Z\",\"Path\":\"terraform-state-982542462374/backend-test.tfstate\"}"
            }
        },
        {
            "Digest": {
                "S": "b72fe49326d8f111c94566d53c2ef176"
            },
            "LockID": {
                "S": "terraform-state-982542462374/backend-test.tfstate-md5"
            }
        }
    ],
    "Count": 2,
    "ScannedCount": 2,
    "ConsumedCapacity": null
}
```
Another method of verifying state lock is to run `terraform plan` or `apply` from a second terminal session while the first `terraform apply` is pending approval. Or have a second user run `terraform plan` or `apply`. When trying to run a `plan` or `apply` on a backend that is locked, Terraform will produce the following error message:
```zsh
$ terraform apply
╷
│ Error: Error acquiring the state lock
│
│ Error message: ConditionalCheckFailedException: The conditional request failed
│ Lock Info:
│   ID:        8ed32e61-d3b0-45f6-8e54-4874151d1421
│   Path:      terraform-state-982542462374/backend-test.tfstate
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
