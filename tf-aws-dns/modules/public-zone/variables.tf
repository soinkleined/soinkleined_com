variable "domain" {
  type        = string
  description = "Apex name of the public hosted zone, such as daveklein.com."

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

variable "github_pages_cname" {
  type        = string
  description = "www CNAME target. Empty skips the apex A, apex AAAA, and www records. Both of these domains use soinkleined.github.io."
  default     = ""

  validation {
    condition     = var.github_pages_cname == "" || can(regex("^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.github_pages_cname))
    error_message = "github_pages_cname must be empty or a hostname."
  }
}

variable "github_pages_owner" {
  type        = string
  description = "GitHub account that owns the Pages verification TXT. The record name is _github-pages-challenge-<owner>."
  default     = "soinkleined"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.github_pages_owner))
    error_message = "github_pages_owner must be a GitHub login."
  }
}

variable "github_pages_challenge" {
  type        = string
  description = "Value of the GitHub Pages domain-verification TXT. Empty omits the record. Paste the token only."
  default     = ""
}

variable "caa_issuers" {
  type        = list(string)
  description = "CAA issue issuers. Empty omits the record. A non-empty list must include letsencrypt.org so GitHub Pages can issue a certificate."
  default     = []
}

variable "records" {
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number)
    records = list(string)
  }))
  description = "Records other than the GitHub Pages set and the optional CAA set. TXT values are split at 255 octets. NS and SOA are rejected."
  default     = {}
}
