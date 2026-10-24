mock_provider "aws" {}

run "creates_nothing_until_a_vpc_is_listed" {
  command = plan

  assert {
    condition     = length(module.zone) == 0
    error_message = "The private root should not create a zone while vpcs is empty."
  }
}

run "creates_a_zone_for_one_vpc" {
  command = plan

  variables {
    vpcs = [{
      vpc_id     = "vpc-0123456789abcdef0"
      vpc_region = "eu-west-2"
    }]
  }

  assert {
    condition     = length(module.zone) == 1
    error_message = "One VPC should create one private zone."
  }
}
