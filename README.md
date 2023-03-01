# cloudformation-terraform-s3-backend
AWS CloudFormation template to create the S3 and DynamoDB resources needed for a Terraform S3 backend.

## Deployment
Open a terminal session and configure the AWS CLI with credentials capable of deploying the `tf-s3-backend.yaml` CloudFormation stack.

Run `./scripts/cfn.sh create-stack` to deploy the CloudFormation stack. Alternatively, the CloudFormation stack can be deployed via the AWS console or integrated into a CI/CD pipeline. A stack set can be used for multi-account deployments.

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
The `-reconfigure` flag may be necessary if `terraform init` ran previously with a different backend configuration and the `.terraform` directory still includes the old configuration. Or, simply delete the outdated test configuration.

Run `terraform apply` and type `yes` to create the `timestamp()` output. For example:
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
$ aws s3 ls <bucket>
2023-02-28 21:57:19        273 backend-test.tfstate
```
To verify the state lock funtionality, run `terraform apply` and let the process hang on the approval step. Run `aws dynamodb scan --table-name <dynamodb-table-name>` from a second terminal session to return the items in the table. There should be an item that includes an `Info` attrubute. Terraform will delete the item containing the `Info` attribute to unlock the state. After the initial state file creation, Terraform will also maintain a peristent item with an md5 hash digest of the state file. The output should be similar to the following:
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
Another method of verifying state lock is to run `terraform plan` or `apply` from a second terminal session while the first `terraform apply` is pending approval. Or, have a second user run `terraform plan` or `apply`. When trying to run a `plan` or `apply` on a backend that is locked, Terraform will produce an error message similar to the following:
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

Refer to HashiCorp's [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3) documentation for more information.
