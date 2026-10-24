variable "aws_region" {
  type        = string
  description = "Region for the state bucket. Route 53 hosted zones are global. us-east-1 matches the Route 53 Domains API."
  default     = "us-east-1"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique name for the Terraform state bucket. Example: soinkleined-dns-tfstate-<account-id>."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name."
  }
}

variable "state_prefix" {
  type        = string
  description = "Key prefix for every domain state object. scripts/tf.sh appends <domain>/<public|private>/terraform.tfstate."
  default     = "domains"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]*$", var.state_prefix)) && !strcontains(var.state_prefix, "..")
    error_message = "state_prefix must be a relative S3 key prefix."
  }
}
