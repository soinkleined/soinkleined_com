provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "dns"
      ManagedBy = "terraform"
      Domain    = "soinkleined.com"
      Scope     = "private"
    }
  }
}
