mock_provider "aws" {}

run "published_mail_strings_and_txt_split" {
  command = plan

  assert {
    condition     = local.spf["daveklein.com"] == "v=spf1 include:_spf.google.com ~all"
    error_message = "daveklein.com SPF drifted from the published record."
  }

  assert {
    condition     = local.spf["soinkleined.com"] == "v=spf1 include:_spf.google.com include:_spf.hostrocket.com ~all"
    error_message = "soinkleined.com SPF must keep the HostRocket include until the flag is flipped."
  }

  assert {
    condition     = local.dmarc["daveklein.com"] == "v=DMARC1;p=quarantine; rua=mailto:info@daveklein.com"
    error_message = "daveklein.com DMARC must match the published TXT, including the space before rua."
  }

  assert {
    condition     = local.dmarc["soinkleined.com"] == "v=DMARC1;p=quarantine; rua=mailto:david@soinkleined.com"
    error_message = "soinkleined.com DMARC must match the published TXT."
  }

  assert {
    condition     = length(local.google_dkim["daveklein.com"]) == 410
    error_message = "daveklein.com DKIM key length changed."
  }

  assert {
    condition     = length(local.google_dkim["soinkleined.com"]) == 410
    error_message = "soinkleined.com Google DKIM key length changed."
  }

  assert {
    condition     = length(local.cpanel_dkim) == 410
    error_message = "cPanel DKIM key length changed."
  }

  assert {
    condition = (
      strcontains(local.chunk_txt[local.google_dkim["daveklein.com"]], "\"\"")
      && !strcontains(substr(local.chunk_txt[local.google_dkim["daveklein.com"]], 0, 255), "\"\"")
    )
    error_message = "DKIM TXT must be split on a 255-octet boundary via the provider's \"\" marker."
  }
}

run "hostrocket_spf_can_be_removed" {
  command = plan

  variables {
    include_hostrocket_spf = false
    include_cpanel_dkim    = false
  }

  assert {
    condition     = local.spf["soinkleined.com"] == "v=spf1 include:_spf.google.com ~all"
    error_message = "Clearing include_hostrocket_spf should leave only the Google include."
  }

  assert {
    condition     = local.spf["daveklein.com"] == "v=spf1 include:_spf.google.com ~all"
    error_message = "daveklein.com SPF must not gain a HostRocket include."
  }

  assert {
    condition     = length(aws_route53_record.cpanel_dkim) == 0
    error_message = "cPanel DKIM record should be absent when include_cpanel_dkim is false."
  }
}
