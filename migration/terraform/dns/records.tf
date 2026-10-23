resource "aws_route53_record" "apex_a" {
  for_each = local.domains

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = each.key
  type    = "A"
  ttl     = var.record_ttl
  records = local.github_pages_a
}

resource "aws_route53_record" "apex_aaaa" {
  for_each = local.domains

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = each.key
  type    = "AAAA"
  ttl     = var.record_ttl
  records = local.github_pages_aaaa
}

resource "aws_route53_record" "www" {
  for_each = local.domains

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = "www.${each.key}"
  type    = "CNAME"
  ttl     = var.record_ttl
  records = [local.github_pages_cname]
}

resource "aws_route53_record" "mx" {
  for_each = local.domains

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = each.key
  type    = "MX"
  ttl     = var.record_ttl
  records = ["1 smtp.google.com"]
}

resource "aws_route53_record" "apex_txt" {
  for_each = local.domains

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = each.key
  type    = "TXT"
  ttl     = var.record_ttl
  records = [
    for value in concat([local.spf[each.key]], lookup(var.extra_apex_txt, each.key, [])) :
    local.chunk_txt[value]
  ]
}

resource "aws_route53_record" "dmarc" {
  for_each = local.domains

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = "_dmarc.${each.key}"
  type    = "TXT"
  ttl     = var.record_ttl
  records = [local.chunk_txt[local.dmarc[each.key]]]
}

resource "aws_route53_record" "google_dkim" {
  for_each = local.domains

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = "google._domainkey.${each.key}"
  type    = "TXT"
  ttl     = var.record_ttl
  records = [local.chunk_txt[local.google_dkim[each.key]]]
}

resource "aws_route53_record" "cpanel_dkim" {
  count = var.include_cpanel_dkim ? 1 : 0

  zone_id = aws_route53_zone.apex["soinkleined.com"].zone_id
  name    = "x._domainkey.soinkleined.com"
  type    = "TXT"
  ttl     = var.record_ttl
  records = [local.chunk_txt[local.cpanel_dkim]]
}

resource "aws_route53_record" "google_app" {
  for_each = {
    for item in flatten([
      for zone, hosts in local.google_app_hosts : [
        for host in hosts : {
          key  = "${host}.${zone}"
          zone = zone
          host = host
        }
      ]
    ]) : item.key => item
  }

  zone_id = aws_route53_zone.apex[each.value.zone].zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = var.record_ttl
  records = ["ghs.googlehosted.com"]
}

resource "aws_route53_record" "github_pages_challenge" {
  for_each = {
    for zone, value in var.github_pages_challenge : zone => value
    if value != ""
  }

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = "_github-pages-challenge-soinkleined.${each.key}"
  type    = "TXT"
  ttl     = var.record_ttl
  records = [local.chunk_txt[each.value]]
}

resource "aws_route53_record" "caa" {
  for_each = {
    for zone, issuers in var.caa_issuers : zone => issuers
    if length(issuers) > 0
  }

  zone_id = aws_route53_zone.apex[each.key].zone_id
  name    = each.key
  type    = "CAA"
  ttl     = var.record_ttl
  records = [for issuer in each.value : "0 issue \"${issuer}\""]

  lifecycle {
    precondition {
      condition     = contains(each.value, "letsencrypt.org")
      error_message = "caa_issuers for ${each.key} must include letsencrypt.org so GitHub Pages can issue a certificate."
    }
  }
}

resource "aws_route53_record" "extra" {
  for_each = var.extra_records

  zone_id = aws_route53_zone.apex[each.value.zone].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = coalesce(each.value.ttl, var.record_ttl)
  records = (
    each.value.type == "TXT"
    ? [for value in each.value.records : local.chunk_txt[value]]
    : each.value.records
  )

  lifecycle {
    precondition {
      condition     = !contains(["NS", "SOA"], each.value.type)
      error_message = "extra_records must not manage NS or SOA (${each.key})."
    }
    precondition {
      condition = (
        !contains(local.reserved_names, each.value.name)
        && !contains(local.reserved_names, "${each.value.name}.${each.value.zone}")
        && !contains(local.reserved_names, trimsuffix(each.value.name, "."))
      )
      error_message = "extra_records ${each.key} collides with a record this module already manages."
    }
  }
}
