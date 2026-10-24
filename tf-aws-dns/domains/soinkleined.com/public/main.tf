resource "terraform_data" "record_inputs" {
  lifecycle {
    precondition {
      condition     = alltrue([for value in var.extra_apex_txt : !startswith(lower(value), "v=spf1")])
      error_message = "SPF belongs in mail.tf. extra_apex_txt is for other apex TXT values, such as a site verification."
    }
    precondition {
      condition     = length(setintersection(toset(keys(local.mail_records)), toset(keys(var.extra_records)))) == 0
      error_message = "extra_records uses a key reserved for mail: ${join(", ", setintersection(toset(keys(local.mail_records)), toset(keys(var.extra_records))))}."
    }
  }
}

module "zone" {
  source = "../../../modules/public-zone"

  domain                 = "soinkleined.com"
  record_ttl             = var.record_ttl
  github_pages_cname     = var.github_pages_cname
  github_pages_challenge = var.github_pages_challenge
  caa_issuers            = var.caa_issuers
  records                = merge(local.mail_records, var.extra_records)
}
