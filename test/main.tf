terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket         = "terraform-state-982542462374"
    key            = "backend-test.tfstate"
    dynamodb_table = "terraform-lock-982542462374"
    region         = "us-east-1"
  }
}

output "current_time" {
  value = timestamp()
}
