# No VPCs means no zone. Instantiating the module with an empty vpc list
# would fail its validation; omitting the vpc block would create a public zone.
module "zone" {
  count  = length(var.vpcs) == 0 ? 0 : 1
  source = "../../../modules/private-zone"

  domain     = "soinkleined.com"
  vpcs       = var.vpcs
  records    = var.records
  record_ttl = var.record_ttl
}
