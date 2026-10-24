variable "aws_region" {
  type        = string
  description = "Provider region. Route 53 hosted zones are global; this region is used for API calls and must match the state bucket."
  default     = "us-east-1"
}

variable "record_ttl" {
  type        = number
  description = "TTL for records this root manages. Keep 300 until the cutover has been clean for a few days."
  default     = 300
}

variable "include_hostrocket_spf" {
  type        = bool
  description = "Keep include:_spf.hostrocket.com on the apex SPF. Set false only after HostRocket cron is disabled and DMARC reports no longer show MailChannels."
  default     = true
}

variable "include_cpanel_dkim" {
  type        = bool
  description = "Keep the cPanel selector x._domainkey. Set false once WordPress is no longer sending mail."
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

variable "github_pages_cname" {
  type        = string
  description = "www CNAME target. Empty skips the GitHub Pages records."
  default     = "soinkleined.github.io"
}

variable "github_pages_challenge" {
  type        = string
  description = "Value of _github-pages-challenge-soinkleined.soinkleined.com. Empty omits the record."
  default     = ""
}

variable "extra_apex_txt" {
  type        = list(string)
  description = "Additional apex TXT values, such as a Google site verification. Merged into the single apex TXT set. Do not put SPF here."
  default     = []
}

variable "caa_issuers" {
  type        = list(string)
  description = "Optional CAA issue issuers. Leave empty: this zone publishes no CAA today. If set, include letsencrypt.org."
  default     = []
}

variable "extra_records" {
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number)
    records = list(string)
  }))
  description = <<-EOT
    Records from the HostRocket zone export that this root does not already manage.
    name may be relative (blog) or a FQDN (blog.soinkleined.com).
    Do not use this for NS, SOA, apex A/AAAA/MX/TXT, www, google._domainkey, _dmarc,
    the Google CNAMEs (mail, calendar, docs), or x._domainkey.
    Do not copy cPanel defaults (cpanel, webmail, whm, ftp, webdisk, autoconfig,
    autodiscover, cpcalendars, cpcontacts) unless something other than the hosting
    panel still resolves them.
  EOT
  default     = {}
}
