resource "aws_route53_zone" "apex" {
  for_each = local.domains

  name    = each.key
  comment = "Public zone for ${each.key}. Not authoritative until the registrar nameserver cutover."

  # Refuses to delete a zone that still has records Terraform does not manage.
  force_destroy = false
}
