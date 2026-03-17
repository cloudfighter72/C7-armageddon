variable "aws_region" {
  description = "AWS Region for lab-1c"
  type        = string
  default     = "us-east-2"
}

variable "lab_1c" {
  description = "lab_1c_name"
  type        = string
  default     = "lab_1c"
}

variable "vpc_cidr" {
  description = "vpc_cidr"
  type        = string
  default     = "10.235.0.0/16" # TODO: student supplies
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(string)
  default     = ["10.235.1.0/24", "10.235.2.0/24", "10.235.3.0/24"] # TODO: student supplies
}

variable "private_subnets" {
  description = "Private subnets"
  type        = list(string)
  default     = ["10.235.11.0/24", "10.235.12.0/24", "10.235.13.0/24"] # TODO: student supplies
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"] # TODO: student supplies
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host"
  type        = string
  default     = "ami-06f1fc9ae5ae7f31e" # TODO
}

variable "ec2_instance_type" {
  description = "EC2 app instance type"
  type        = string
  default     = "t3.micro"
}

variable "aws_key_pair_name" {
  description = "Name of the keypair to use for EC2 instances."
  type        = string
  default     = "ec2-lab-app"
}

variable "db_engine" {
  description = "RDS engine"
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "rds_db"
  type        = string
  default     = "rds_db" # Students can change
}

variable "db_username" {
  description = "admin"
  type        = string
  default     = "admin" # TODO: student supplies
}

variable "db_password" {
  description = "Cside8787"
  type        = string
  sensitive   = true
  default     = "Cside8787" # TODO: student supplies
}

variable "sns_email_endpoint" {
  description = "Email for SNS subscription (PagerDuty simulation)."
  type        = string
  default     = "cloudfighter72@gmail.com" # TODO: student supplies
}

variable "db_parameters_for_ssm_parameter" {
  description = "Database parameters stored in SSM Parameter Store"
  type        = map(string)
  default = {
    endpoint = "lab-1a-db.cdiu8yo22mzm.us-east-2.rds.amazonaws.com"
    port     = "3306"
    "name"   = "lab-1a-db"
  }
}

# Source - https://stackoverflow.com/a
# Posted by Marko E, modified by community. See post 'Timeline' for change history

resource "aws_ssm_parameter" "db-parameters-for-1b" {
  for_each = var.db_parameters_for_ssm_parameter
  name     = "/armageddon1n/database/${each.key}"
  type     = "SecureString"
  value    = each.value
}