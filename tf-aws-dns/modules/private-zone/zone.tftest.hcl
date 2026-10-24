mock_provider "aws" {}

run "zone_takes_the_vpc" {
  command = plan

  variables {
    domain = "example.com"
    vpcs = [{
      vpc_id     = "vpc-0123456789abcdef0"
      vpc_region = "eu-west-2"
    }]
  }

  assert {
    condition     = aws_route53_zone.this.name == "example.com"
    error_message = "Private zone name should be the domain."
  }

  assert {
    condition     = length(aws_route53_zone.this.vpc) == 1
    error_message = "The private zone should carry the VPC it was given."
  }
}
