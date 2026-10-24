variable "domain" {
  type        = string
  description = "Apex name of the private hosted zone. Callers pass a VPC list; an empty list is rejected so this module cannot accidentally create a public zone."

  validation {
    condition     = can(regex("^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.domain))
    error_message = "domain must be a lowercase DNS name."
  }
}

variable "comment" {
  type        = string
  description = "Hosted zone comment. Empty uses the default."
  default     = null
}

variable "record_ttl" {
  type        = number
  description = "TTL for records this module manages."
  default     = 300

  validation {
    condition     = var.record_ttl >= 60 && var.record_ttl <= 86400
    error_message = "record_ttl must be between 60 and 86400."
  }
}

variable "vpcs" {
  type = list(object({
    vpc_id     = string
    vpc_region = string
  }))
  description = "VPCs that resolve this zone. The first is sent on CreateHostedZone. Further VPCs are associated afterwards. Same-account only."

  validation {
    condition = (
      length(var.vpcs) > 0
      && length(distinct([for vpc in var.vpcs : vpc.vpc_id])) == length(var.vpcs)
      && alltrue([
        for vpc in var.vpcs :
        can(regex("^vpc-[0-9a-f]{8,17}$", vpc.vpc_id)) && can(regex("^[a-z]{2}-[a-z]+-\\d+$", vpc.vpc_region))
      ])
    )
    error_message = "vpcs needs at least one unique vpc- id and a region such as eu-west-2."
  }
}

variable "records" {
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number)
    records = list(string)
  }))
  description = "Records visible only inside the associated VPCs. TXT values are split at 255 octets. NS and SOA are rejected. Do not copy the public mail set in here unless a VPC resolver needs it."
  default     = {}
}
