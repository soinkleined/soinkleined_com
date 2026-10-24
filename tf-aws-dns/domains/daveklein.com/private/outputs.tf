output "zone_id" {
  description = "Private hosted zone ID, or null while vpcs is empty."
  value       = length(module.zone) == 0 ? null : module.zone[0].zone_id
}

output "name_servers" {
  description = "Nameservers of the daveklein.com private zone, or null while vpcs is empty. These are not a public delegation set."
  value       = length(module.zone) == 0 ? null : module.zone[0].name_servers
}
