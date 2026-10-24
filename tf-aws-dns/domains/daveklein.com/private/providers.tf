provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "dns"
      ManagedBy = "terraform"
      Domain    = "daveklein.com"
      Scope     = "private"
    }
  }
}
