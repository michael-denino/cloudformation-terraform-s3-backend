terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket         = "<s3-bucket-name>"
    key            = "backend-test.tfstate"
    dynamodb_table = "<dynamodb-table-name>"
    region         = "<aws-region>"
  }
}

output "current_time" {
  description = "Timestamp represented in RFC 3339 date and time format."
  value       = timestamp()
}
