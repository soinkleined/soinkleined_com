terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial backend. Supply the rest from backend.hcl (see backend.hcl.example).
  # Native S3 lockfiles need Terraform >= 1.10. DynamoDB locking is deprecated.
  backend "s3" {}
}
