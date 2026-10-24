locals {
  # Apex TXT as published on 23 Oct 2026, including the HostRocket include
  # until include_hostrocket_spf is set false.
  spf = var.include_hostrocket_spf ? (
    "v=spf1 include:_spf.google.com include:_spf.hostrocket.com ~all"
    ) : (
    "v=spf1 include:_spf.google.com ~all"
  )

  # Space before rua, nowhere else.
  dmarc = "v=DMARC1;p=${var.dmarc_policy}; rua=mailto:david@soinkleined.com"

  google_dkim = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjQZc3HmpD3Ae7rtNuXjI6K4iSrdAqkiC6Bf5rZrxfPkQKMTEbso3eW2+Mqe1bf6FmhAwpI7AGGSMg+FuvlHSuKkcK2BSLlPyQQnEp5bGZzGy8BDSvrQ/8F44H+ptyEAjVC6t/6UiTBW+egxhDiSEuhWW5PmbMHEDPuvKXPsCQk5n0MpZJcnpSZwn0yn1X8YOnbNffoyMeyi1+MTf9g52HsnXE7hZZEPunjGrbLLM4ZHl7bZSt+tG78Oe9CrmwsIMXuIUzOX/QXq5FFI2IrkkMG9MQINjvLIY77cvdNppUq/CK8evDBonV6R+j88YOOZXculbmMReWLirWTt8pH7LzQIDAQAB"

  # cPanel / MailChannels selector. Not a Google key.
  cpanel_dkim = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtBY926BOjQmZX/ylT5KX2Y6tsd3DhTG8mJz0CfmKlOrt3qAOkgPAEkcob/W5fpv+mnUHQCoj2jaWxRneiX5DNJkwYBjieqjUCgE2z5eAyIG/8CGwrp50D/QE8GAppQnHcxjDsUCxEIK2HD8YErkMpsYolx9sRA0m9JJxihXaFWX9qK3ozFESFOmJQEpHkgHrW+dlIDpeIooESMhbTNwgRomkXcq9V7g+e6t8xNPecT4Cl+/oafPQUJ5P6kK7hYUqZRxjmcBi6Yo2LU2xuRZ300SFbd3ydG3IwqsD3SZ/K9ACfmuCFPswzlbDMzEIEl1ERJAjaU5feWlJOtaZAvF8nQIDAQAB"

  mail_records = merge(
    {
      mx = {
        name    = "soinkleined.com"
        type    = "MX"
        ttl     = null
        records = ["1 smtp.google.com"]
      }
      apex_txt = {
        name    = "soinkleined.com"
        type    = "TXT"
        ttl     = null
        records = concat([local.spf], var.extra_apex_txt)
      }
      dmarc = {
        name    = "_dmarc.soinkleined.com"
        type    = "TXT"
        ttl     = null
        records = [local.dmarc]
      }
      google_dkim = {
        name    = "google._domainkey.soinkleined.com"
        type    = "TXT"
        ttl     = null
        records = [local.google_dkim]
      }
      mail = {
        name    = "mail.soinkleined.com"
        type    = "CNAME"
        ttl     = null
        records = ["ghs.googlehosted.com"]
      }
      calendar = {
        name    = "calendar.soinkleined.com"
        type    = "CNAME"
        ttl     = null
        records = ["ghs.googlehosted.com"]
      }
      docs = {
        name    = "docs.soinkleined.com"
        type    = "CNAME"
        ttl     = null
        records = ["ghs.googlehosted.com"]
      }
    },
    {
      for key, rec in {
        cpanel_dkim = {
          name    = "x._domainkey.soinkleined.com"
          type    = "TXT"
          ttl     = null
          records = [local.cpanel_dkim]
        }
      } : key => rec if var.include_cpanel_dkim
    },
  )
}
