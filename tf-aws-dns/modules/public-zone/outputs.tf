output "zone_id" {
  description = "Hosted zone ID."
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Delegation set assigned by Route 53. The registrar must list exactly these nameservers at cutover."
  value       = aws_route53_zone.this.name_servers
}

output "txt_chunks" {
  description = "TXT values after the 255-octet split. The \"\" marker is the provider boundary, not part of the published text."
  value       = local.chunk_txt
}
