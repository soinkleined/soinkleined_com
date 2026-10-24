terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial backend. scripts/tf.sh passes backend.hcl plus the state key.
  # Native S3 lockfiles need Terraform >= 1.10.
  backend "s3" {}
}
