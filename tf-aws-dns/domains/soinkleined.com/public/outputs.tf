output "zone_id" {
  description = "Hosted zone ID. Use this for terraform import and for the registrar cutover cross-check."
  value       = module.zone.zone_id
}

output "name_servers" {
  description = "Delegation set for soinkleined.com. The registrar must list exactly these nameservers at cutover, and no others."
  value       = module.zone.name_servers
}
