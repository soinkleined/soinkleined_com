variable "aws_region" {
  type        = string
  description = "Provider region. Route 53 hosted zones are global; this region is used for API calls and must match the state bucket."
  default     = "us-east-1"
}

variable "record_ttl" {
  type        = number
  description = "TTL for records in the private zone."
  default     = 300
}

variable "vpcs" {
  type = list(object({
    vpc_id     = string
    vpc_region = string
  }))
  description = "VPCs that should resolve soinkleined.com privately. Empty creates no zone. Do not apply a public copy of the mail records here."
  default     = []
}

variable "records" {
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number)
    records = list(string)
  }))
  description = "Names that exist only inside the associated VPCs."
  default     = {}
}
