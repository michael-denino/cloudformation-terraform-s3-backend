terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket         = "<s3-bucket-name>"
    key            = "<state-file-name>.tfstate"
    dynamodb_table = "<dynamodb-table-name>"
    region         = "<aws-region>"
  }
}

output "current_time" {
  value = timestamp()
}
