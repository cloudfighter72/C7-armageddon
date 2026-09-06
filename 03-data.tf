############################################
# Data sources + locals
############################################

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Newest Amazon Linux 2023 image, so the config does not break when AWS
# retires the AMI ID you hardcoded last semester.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ami_id = coalesce(var.ec2_ami_id, data.aws_ami.al2023.id)

  azs = slice(
    data.aws_availability_zones.available.names,
    0,
    max(length(var.public_subnets), length(var.private_subnets))
  )
}