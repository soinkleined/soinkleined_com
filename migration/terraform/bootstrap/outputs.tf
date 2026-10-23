output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "state_key" {
  value = var.state_key
}

output "aws_region" {
  value = var.aws_region
}

output "terraform_dns_policy_arn" {
  value = aws_iam_policy.terraform_dns.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
