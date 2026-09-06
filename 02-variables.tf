############################################
# Core
############################################

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-2"
}

############################################
# Names
#
# These defaults match the identifiers used by the CLI verification
# commands in section 6 of the lab document. Change them and you must
# change those commands too.
############################################

variable "ec2_name" {
  description = "Name tag on the EC2 instance. Used by section 6.1."
  type        = string
  default     = "lab-ec2-app"
}

variable "ec2_sg_name" {
  description = "Name of the EC2 security group."
  type        = string
  default     = "lab-sg-ec2"

  validation {
    condition     = !startswith(var.ec2_sg_name, "sg-")
    error_message = "AWS reserves the sg- prefix for security group IDs. Use lab-sg-ec2."
  }
}

variable "rds_sg_name" {
  description = "Name of the RDS security group. AWS rejects names starting with sg-."
  type        = string
  default     = "lab-sg-rds"

  validation {
    condition     = !startswith(var.rds_sg_name, "sg-")
    error_message = "AWS reserves the sg- prefix for security group IDs. Use lab-sg-rds."
  }
}

variable "db_identifier" {
  description = "RDS instance identifier. Used by sections 6.3 and 6.4."
  type        = string
  default     = "lab-mysql"
}

variable "secret_name" {
  description = "Secrets Manager secret ID. Used by section 6.6."
  type        = string
  default     = "lab/rds/mysql"
}

############################################
# Networking
############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnets" {
  description = "CIDR blocks for the public subnets. The app host lives in the first one."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for the private subnets. RDS requires at least two AZs."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "An RDS subnet group needs at least two subnets in different AZs."
  }
}

############################################
# Access control
############################################

variable "http_ingress_cidrs" {
  description = "CIDRs allowed to reach the app on port 80."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_ingress_cidrs" {
  description = "CIDRs allowed to SSH to the app host. Use your own /32."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.ssh_ingress_cidrs, "0.0.0.0/0")
    error_message = "Do not open SSH to the world. Use your own /32."
  }
}

############################################
# EC2
############################################

variable "ec2_instance_type" {
  description = "Instance type for the app host."
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami_id" {
  description = "AMI for the app host. Leave null to use the newest Amazon Linux 2023 image."
  type        = string
  default     = null
}

variable "aws_key_pair_name" {
  description = "Existing EC2 key pair for SSH. Leave null to use SSM Session Manager only."
  type        = string
  default     = null
}

############################################
# RDS
############################################

variable "db_engine_version" {
  description = "MySQL major version."
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database created on the RDS instance."
  type        = string
  default     = "labdb"
}

variable "db_username" {
  description = "Master username. The lab's section 6.7 logs in as this user."
  type        = string
  default     = "admin"
}

variable "db_port" {
  description = "Database port."
  type        = number
  default     = 3306
}