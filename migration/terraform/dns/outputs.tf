output "zone_ids" {
  description = "Hosted zone IDs. Use these for terraform import and for the registrar cutover cross-check."
  value       = { for zone, resource in aws_route53_zone.apex : zone => resource.zone_id }
}

output "name_servers" {
  description = "Delegation set assigned by Route 53. The registrar must list exactly these nameservers at cutover, and no others."
  value       = { for zone, resource in aws_route53_zone.apex : zone => resource.name_servers }
}
