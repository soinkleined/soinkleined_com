locals {
  txt_values = distinct(flatten([
    for rec in values(var.records) : rec.type == "TXT" ? rec.records : []
  ]))

  chunk_txt = {
    for value in local.txt_values : value => join("\"\"", [
      for offset in range(0, length(value), 255) : substr(value, offset, 255)
    ]) if value != ""
  }

  record_pairs = [for rec in values(var.records) : "${trimsuffix(rec.name, ".")}|${rec.type}"]
}

resource "aws_route53_zone" "this" {
  name    = var.domain
  comment = coalesce(var.comment, "Private zone for ${var.domain}. Only the associated VPCs resolve it.")

  # A private zone with no VPC is a public zone. The variable validation refuses that.
  dynamic "vpc" {
    for_each = { for vpc in var.vpcs : vpc.vpc_id => vpc }
    content {
      vpc_id     = vpc.value.vpc_id
      vpc_region = vpc.value.vpc_region
    }
  }

  force_destroy = false
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
  }
}
