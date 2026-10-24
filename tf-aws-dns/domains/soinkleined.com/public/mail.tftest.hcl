mock_provider "aws" {}

run "published_mail_strings_and_txt_split" {
  command = plan

  assert {
    condition     = local.spf == "v=spf1 include:_spf.google.com include:_spf.hostrocket.com ~all"
    error_message = "soinkleined.com SPF must keep the HostRocket include until the flag is flipped."
  }

  assert {
    condition     = local.dmarc == "v=DMARC1;p=quarantine; rua=mailto:david@soinkleined.com"
    error_message = "soinkleined.com DMARC must match the published TXT, including the space before rua."
  }

  assert {
    condition     = length(local.google_dkim) == 410 && length(local.cpanel_dkim) == 410
    error_message = "DKIM key length changed."
  }

  assert {
    condition     = contains(keys(local.mail_records), "cpanel_dkim")
    error_message = "cPanel DKIM should be present while include_cpanel_dkim is true."
  }

  assert {
    condition = (
      strcontains(module.zone.txt_chunks[local.google_dkim], "\"\"")
      && !strcontains(substr(module.zone.txt_chunks[local.google_dkim], 0, 255), "\"\"")
      && strcontains(module.zone.txt_chunks[local.cpanel_dkim], "\"\"")
    )
    error_message = "DKIM TXT must be split on a 255-octet boundary via the provider's \"\" marker."
  }
}

run "hostrocket_mail_can_be_removed" {
  command = plan

  variables {
    include_hostrocket_spf = false
    include_cpanel_dkim    = false
  }

  assert {
    condition     = local.spf == "v=spf1 include:_spf.google.com ~all"
    error_message = "Clearing include_hostrocket_spf should leave only the Google include."
  }

  assert {
    condition     = contains(keys(local.mail_records), "cpanel_dkim") == false
    error_message = "cPanel DKIM should be absent when include_cpanel_dkim is false."
  }
}
