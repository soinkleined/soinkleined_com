variable "aws_region" {
  type        = string
  description = "Provider region. Route 53 hosted zones are global; this region is used for API calls and must match the state bucket."
  default     = "us-east-1"
}

variable "record_ttl" {
  type        = number
  description = "TTL for records this config manages. Keep 300 until the cutover has been clean for a few days."
  default     = 300

  validation {
    condition     = var.record_ttl >= 60 && var.record_ttl <= 86400
    error_message = "record_ttl must be between 60 and 86400."
  }
}

variable "include_hostrocket_spf" {
  type        = bool
  description = "Keep include:_spf.hostrocket.com on soinkleined.com. daveklein.com never had it. Set false only after HostRocket cron is disabled and DMARC reports no longer show MailChannels."
  default     = true
}

variable "include_cpanel_dkim" {
  type        = bool
  description = "Keep the cPanel selector x._domainkey on soinkleined.com. Set false once WordPress is no longer sending mail."
  default     = true
}

variable "dmarc_policy" {
  type        = string
  description = "DMARC p= value. Live policy on 23 Oct 2026 is quarantine. Move to reject only after aggregate reports are clean."
  default     = "quarantine"

  validation {
    condition     = contains(["none", "quarantine", "reject"], var.dmarc_policy)
    error_message = "dmarc_policy must be none, quarantine, or reject."
  }
}

variable "github_pages_challenge" {
  type        = map(string)
  description = "Per-zone value of _github-pages-challenge-soinkleined, from GitHub domain verification. Empty string omits the record. Paste the token only."
  default = {
    "daveklein.com"   = ""
    "soinkleined.com" = ""
  }
}

variable "extra_apex_txt" {
  type        = map(list(string))
  description = "Additional apex TXT values (Google site verification and anything else in the zone export). Merged into the single apex TXT record set. Do not put SPF here."
  default = {
    "daveklein.com"   = []
    "soinkleined.com" = []
  }
}

variable "caa_issuers" {
  type        = map(list(string))
  description = "Optional per-zone CAA issue issuers. Leave empty: neither zone publishes CAA today. If set, include letsencrypt.org or GitHub Pages cannot issue a certificate."
  default     = {}
}

variable "extra_records" {
  type = map(object({
    zone    = string
    name    = string
    type    = string
    ttl     = optional(number)
    records = list(string)
  }))
  description = <<-EOT
    Records that show up in the HostRocket zone export and are not already managed here.
    name may be relative (blog) or a FQDN (blog.daveklein.com).
    Do not use this for NS, SOA, apex A/AAAA/MX/TXT, www, google._domainkey, _dmarc,
    the GitHub challenge name, soinkleined.com Google CNAMEs, or x._domainkey.
    Do not copy cPanel defaults (cpanel, webmail, whm, ftp, webdisk, autoconfig,
    autodiscover, cpcalendars, cpcontacts) unless something other than the hosting
    panel still resolves them.
  EOT
  default     = {}
}
