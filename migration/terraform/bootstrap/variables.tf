variable "aws_region" {
  type        = string
  description = "Region for the state bucket. Route 53 itself is global. us-east-1 matches the Route 53 Domains API."
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

variable "state_key" {
  type        = string
  description = "Object key of the DNS workspace state. Must match migration/terraform/dns/backend.hcl."
  default     = "dns/terraform.tfstate"
}
