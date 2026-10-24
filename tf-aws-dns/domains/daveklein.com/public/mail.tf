locals {
  # Apex TXT as published on 23 Oct 2026. This zone has no HostRocket include.
  spf = "v=spf1 include:_spf.google.com ~all"

  # Space before rua, nowhere else.
  dmarc = "v=DMARC1;p=${var.dmarc_policy}; rua=mailto:info@daveklein.com"

  # google._domainkey TXT, character-strings joined. The module re-splits at 255.
  google_dkim = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3VfGVHpjiGGP5/Ey1rFbt0E2ad91UYtyRg4ox3pcg3R+C7IgmCwoH2fil4Om6VO3ZqtsnXZkOmCvXef3BbGX5hINlB6Y7SE2txHiigNOMBcBxcUOy15DCzMrFS99ny5AmaxMnuoAJmwPaOb4/kt5HI1D1NULtWGOTA3fKgbAf+0a0hakK9OWz1+LAONKqMP5Cu9YFoZN3NObp06mLnTIyhB5i90W7579s5EgvrN5HoQMLLT8IeNAf9/CiC4E2HdtPaMplWcWIaIg3Eic9wK7m15x7ozRh86vC9NrE1oVXABpEodZAnuW3LrTyt5/+Gal5nVDbmd6WiCqb65BsXrXIQIDAQAB"

  mail_records = {
    mx = {
      name    = "daveklein.com"
      type    = "MX"
      ttl     = null
      records = ["1 smtp.google.com"]
    }
    apex_txt = {
      name    = "daveklein.com"
      type    = "TXT"
      ttl     = null
      records = concat([local.spf], var.extra_apex_txt)
    }
    dmarc = {
      name    = "_dmarc.daveklein.com"
      type    = "TXT"
      ttl     = null
      records = [local.dmarc]
    }
    google_dkim = {
      name    = "google._domainkey.daveklein.com"
      type    = "TXT"
      ttl     = null
      records = [local.google_dkim]
    }
  }
}
