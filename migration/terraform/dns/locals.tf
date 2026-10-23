locals {
  # GitHub Pages anycast addresses, from the GitHub docs checked 23 Oct 2026.
  # Re-read that page before the first apply; do not invent replacements.
  github_pages_a = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
  ]
  github_pages_aaaa = [
    "2606:50c0:8000::153",
    "2606:50c0:8001::153",
    "2606:50c0:8002::153",
    "2606:50c0:8003::153",
  ]
  # Both zones are project sites under the soinkleined account, so both www
  # CNAMEs target the user Pages hostname. GitHub dispatches on the Host header.
  github_pages_cname = "soinkleined.github.io"

  # Apex TXT as published on 23 Oct 2026. daveklein.com has no HostRocket include.
  spf = {
    "daveklein.com" = "v=spf1 include:_spf.google.com ~all"
    "soinkleined.com" = var.include_hostrocket_spf ? (
      "v=spf1 include:_spf.google.com include:_spf.hostrocket.com ~all"
      ) : (
      "v=spf1 include:_spf.google.com ~all"
    )
  }

  # Space before rua, nowhere else. Matches the published TXT when
  # dmarc_policy is "quarantine".
  dmarc_rua = {
    "daveklein.com"   = "mailto:info@daveklein.com"
    "soinkleined.com" = "mailto:david@soinkleined.com"
  }
  dmarc = {
    for zone, rua in local.dmarc_rua : zone => "v=DMARC1;p=${var.dmarc_policy}; rua=${rua}"
  }

  # google._domainkey TXT, character-strings joined (Route 53 will be re-split at 255).
  google_dkim = {
    "daveklein.com"   = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3VfGVHpjiGGP5/Ey1rFbt0E2ad91UYtyRg4ox3pcg3R+C7IgmCwoH2fil4Om6VO3ZqtsnXZkOmCvXef3BbGX5hINlB6Y7SE2txHiigNOMBcBxcUOy15DCzMrFS99ny5AmaxMnuoAJmwPaOb4/kt5HI1D1NULtWGOTA3fKgbAf+0a0hakK9OWz1+LAONKqMP5Cu9YFoZN3NObp06mLnTIyhB5i90W7579s5EgvrN5HoQMLLT8IeNAf9/CiC4E2HdtPaMplWcWIaIg3Eic9wK7m15x7ozRh86vC9NrE1oVXABpEodZAnuW3LrTyt5/+Gal5nVDbmd6WiCqb65BsXrXIQIDAQAB"
    "soinkleined.com" = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjQZc3HmpD3Ae7rtNuXjI6K4iSrdAqkiC6Bf5rZrxfPkQKMTEbso3eW2+Mqe1bf6FmhAwpI7AGGSMg+FuvlHSuKkcK2BSLlPyQQnEp5bGZzGy8BDSvrQ/8F44H+ptyEAjVC6t/6UiTBW+egxhDiSEuhWW5PmbMHEDPuvKXPsCQk5n0MpZJcnpSZwn0yn1X8YOnbNffoyMeyi1+MTf9g52HsnXE7hZZEPunjGrbLLM4ZHl7bZSt+tG78Oe9CrmwsIMXuIUzOX/QXq5FFI2IrkkMG9MQINjvLIY77cvdNppUq/CK8evDBonV6R+j88YOOZXculbmMReWLirWTt8pH7LzQIDAQAB"
  }

  # cPanel / MailChannels selector on soinkleined.com only. Not a Google key.
  cpanel_dkim = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtBY926BOjQmZX/ylT5KX2Y6tsd3DhTG8mJz0CfmKlOrt3qAOkgPAEkcob/W5fpv+mnUHQCoj2jaWxRneiX5DNJkwYBjieqjUCgE2z5eAyIG/8CGwrp50D/QE8GAppQnHcxjDsUCxEIK2HD8YErkMpsYolx9sRA0m9JJxihXaFWX9qK3ozFESFOmJQEpHkgHrW+dlIDpeIooESMhbTNwgRomkXcq9V7g+e6t8xNPecT4Cl+/oafPQUJ5P6kK7hYUqZRxjmcBi6Yo2LU2xuRZ300SFbd3ydG3IwqsD3SZ/K9ACfmuCFPswzlbDMzEIEl1ERJAjaU5feWlJOtaZAvF8nQIDAQAB"

  # Custom Google Workspace URLs that exist today. daveklein.com has none.
  google_app_hosts = {
    "soinkleined.com" = ["mail", "calendar", "docs"]
  }

  domains = toset(["daveklein.com", "soinkleined.com"])

  # Route 53 character-strings are 255 octets. The AWS provider treats "" inside
  # a TXT value as the split between character-strings.
  txt_values = distinct(concat(
    values(local.spf),
    values(local.dmarc),
    values(local.google_dkim),
    [local.cpanel_dkim],
    flatten(values(var.extra_apex_txt)),
    values(var.github_pages_challenge),
    flatten([
      for rec in values(var.extra_records) : rec.type == "TXT" ? rec.records : []
    ]),
  ))

  chunk_txt = {
    for value in local.txt_values : value => join("\"\"", [
      for offset in range(0, length(value), 255) : substr(value, offset, 255)
    ]) if value != ""
  }

  reserved_names = toset(flatten([
    for zone in local.domains : [
      zone,
      "${zone}.",
      "www.${zone}",
      "www.${zone}.",
      "google._domainkey.${zone}",
      "google._domainkey.${zone}.",
      "_dmarc.${zone}",
      "_dmarc.${zone}.",
      "_github-pages-challenge-soinkleined.${zone}",
      "_github-pages-challenge-soinkleined.${zone}.",
      "x._domainkey.soinkleined.com",
      "x._domainkey.soinkleined.com.",
      "mail.soinkleined.com",
      "mail.soinkleined.com.",
      "calendar.soinkleined.com",
      "calendar.soinkleined.com.",
      "docs.soinkleined.com",
      "docs.soinkleined.com.",
    ]
  ]))
}
