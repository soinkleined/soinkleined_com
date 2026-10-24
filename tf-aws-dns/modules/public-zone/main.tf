locals {
  # GitHub Pages anycast addresses, from the GitHub docs checked 23 Oct 2026.
  # Re-read that page before the first apply.
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

  challenge_name = "_github-pages-challenge-${var.github_pages_owner}.${var.domain}"

  # Route 53 character-strings are 255 octets. The AWS provider treats "" inside
  # a TXT value as the split between character-strings.
  txt_values = distinct(concat(
    flatten([
      for rec in values(var.records) : rec.type == "TXT" ? rec.records : []
    ]),
    var.github_pages_challenge == "" ? [] : [var.github_pages_challenge],
  ))

  chunk_txt = {
    for value in local.txt_values : value => join("\"\"", [
      for offset in range(0, length(value), 255) : substr(value, offset, 255)
    ]) if value != ""
  }

  pages_pairs = toset([
    for pair in [
      "${var.domain}|A",
      "${var.domain}.|A",
      "${var.domain}|AAAA",
      "${var.domain}.|AAAA",
      "www.${var.domain}|CNAME",
      "www.${var.domain}.|CNAME",
      "www|CNAME",
    ] : pair if var.github_pages_cname != ""
  ])

  challenge_pairs = toset([
    for pair in [
      "${local.challenge_name}|TXT",
      "${local.challenge_name}.|TXT",
      "_github-pages-challenge-${var.github_pages_owner}|TXT",
    ] : pair if var.github_pages_challenge != ""
  ])

  caa_pairs = toset([
    for pair in [
      "${var.domain}|CAA",
      "${var.domain}.|CAA",
    ] : pair if length(var.caa_issuers) > 0
  ])

  managed_pairs = setunion(local.pages_pairs, local.challenge_pairs, local.caa_pairs)

  record_pairs = [for rec in values(var.records) : "${trimsuffix(rec.name, ".")}|${rec.type}"]
}

resource "aws_route53_zone" "this" {
  name    = var.domain
  comment = coalesce(var.comment, "Public zone for ${var.domain}. Not authoritative until the registrar nameserver cutover.")

  # Refuses to delete a zone that still has records Terraform does not manage.
  force_destroy = false
}

resource "aws_route53_record" "github_pages_a" {
  count = var.github_pages_cname == "" ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "A"
  ttl     = var.record_ttl
  records = local.github_pages_a
}

resource "aws_route53_record" "github_pages_aaaa" {
  count = var.github_pages_cname == "" ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "AAAA"
  ttl     = var.record_ttl
  records = local.github_pages_aaaa
}

resource "aws_route53_record" "www" {
  count = var.github_pages_cname == "" ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = "www.${var.domain}"
  type    = "CNAME"
  ttl     = var.record_ttl
  records = [var.github_pages_cname]
}

resource "aws_route53_record" "github_pages_challenge" {
  count = var.github_pages_challenge == "" ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = local.challenge_name
  type    = "TXT"
  ttl     = var.record_ttl
  records = [local.chunk_txt[var.github_pages_challenge]]
}

resource "aws_route53_record" "caa" {
  count = length(var.caa_issuers) == 0 ? 0 : 1

  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "CAA"
  ttl     = var.record_ttl
  records = [for issuer in var.caa_issuers : "0 issue \"${issuer}\""]

  lifecycle {
    precondition {
      condition     = contains(var.caa_issuers, "letsencrypt.org")
      error_message = "caa_issuers must include letsencrypt.org so GitHub Pages can issue a certificate."
    }
  }
}

resource "terraform_data" "record_names" {
  input = local.record_pairs

  lifecycle {
    precondition {
      condition     = length(local.record_pairs) == length(distinct(local.record_pairs))
      error_message = "records contains two entries with the same name and type."
    }
  }
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
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
      error_message = "records must not manage NS or SOA (${each.key}). Those belong to the hosted zone."
    }
    precondition {
      condition     = each.value.type != "TXT" || alltrue([for value in each.value.records : length(value) > 0])
      error_message = "TXT record ${each.key} has an empty value."
    }
    precondition {
      condition = (
        !contains(local.managed_pairs, "${each.value.name}|${each.value.type}")
        && !contains(local.managed_pairs, "${trimsuffix(each.value.name, ".")}|${each.value.type}")
      )
      error_message = "records ${each.key} collides with a GitHub Pages or CAA record this module manages."
    }
  }
}
