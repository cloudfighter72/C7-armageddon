############################################
# Providers
############################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Lab       = "ec2-rds-integration"
      ManagedBy = "terraform"
    }
  }
}