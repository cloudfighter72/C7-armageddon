############################################
# Terraform + provider versions, remote state
############################################

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.63"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  backend "s3" {
    bucket       = "armageddon-bucket1"
    key          = "theolabs/ec2-rds-lab.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}