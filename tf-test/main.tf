terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket         = "dev-test-cfn-terraform-backend"
    key            = "test-backend.tfstate"
    dynamodb_table = "dev-test-cfn-terraform-backend"
    region         = "us-east-1"
  }
}

output "current_time" {
  value = timestamp()
}
