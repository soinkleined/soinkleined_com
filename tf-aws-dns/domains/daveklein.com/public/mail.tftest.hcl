mock_provider "aws" {}

run "published_mail_strings_and_txt_split" {
  command = plan

  assert {
    condition     = local.spf == "v=spf1 include:_spf.google.com ~all"
    error_message = "daveklein.com SPF drifted from the published record."
  }

  assert {
    condition     = local.dmarc == "v=DMARC1;p=quarantine; rua=mailto:info@daveklein.com"
    error_message = "daveklein.com DMARC must match the published TXT, including the space before rua."
  }

  assert {
    condition     = length(local.google_dkim) == 410
    error_message = "daveklein.com DKIM key length changed."
  }

  assert {
    condition = (
      strcontains(module.zone.txt_chunks[local.google_dkim], "\"\"")
      && !strcontains(substr(module.zone.txt_chunks[local.google_dkim], 0, 255), "\"\"")
    )
    error_message = "DKIM TXT must be split on a 255-octet boundary via the provider's \"\" marker."
  }
}

run "dmarc_reject_keeps_the_rua_spacing" {
  command = plan

  variables {
    dmarc_policy = "reject"
  }

  assert {
    condition     = local.dmarc == "v=DMARC1;p=reject; rua=mailto:info@daveklein.com"
    error_message = "reject must keep the space before rua."
  }
}
