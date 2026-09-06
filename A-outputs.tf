############################################
# Outputs
############################################

output "application_urls" {
  description = "Section 6.8: browser checks, in order."
  value       = <<-EOT
    Home:      http://${aws_instance.app.public_ip}/
    Health:    http://${aws_instance.app.public_ip}/health
    Init DB:   http://${aws_instance.app.public_ip}/init
    Add note:  http://${aws_instance.app.public_ip}/add?note=cloud_labs_are_real
    List:      http://${aws_instance.app.public_ip}/list
  EOT
}

output "ec2_instance_id" {
  description = "Instance ID for section 6.2 and for aws ssm start-session."
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Public IP of the app host."
  value       = aws_instance.app.public_ip
}

output "ec2_security_group_id" {
  description = "EC2 security group ID. This is the source you should see in the RDS inbound rule."
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.rds.id
}

output "rds_endpoint" {
  description = "RDS endpoint hostname for section 6.4 and 6.7."
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS port."
  value       = aws_db_instance.main.port
}

output "db_secret_name" {
  description = "Secrets Manager secret ID for section 6.6."
  value       = aws_secretsmanager_secret.db.name
}

output "db_password" {
  description = "Master password. Read with: terraform output -raw db_password"
  value       = random_password.db.result
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the lab VPC."
  value       = aws_vpc.main.id
}

############################################
# Verification helpers
############################################

output "verify_commands" {
  description = "Copy-paste versions of the section 6 checks, with real IDs filled in."
  value       = <<-EOT
    # 6.1 EC2 instance
    aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=${var.ec2_name}" \
      --query "Reservations[].Instances[].[InstanceId,State.Name]"

    # 6.2 IAM instance profile attached
    aws ec2 describe-instances \
      --instance-ids ${aws_instance.app.id} \
      --query "Reservations[].Instances[].IamInstanceProfile.Arn"

    # 6.3 RDS status
    aws rds describe-db-instances \
      --db-instance-identifier ${var.db_identifier} \
      --query "DBInstances[].DBInstanceStatus"

    # 6.4 RDS endpoint
    aws rds describe-db-instances \
      --db-instance-identifier ${var.db_identifier} \
      --query "DBInstances[].Endpoint"

    # 6.5 RDS inbound rules. Note: --group-names only works in a default
    # VPC, so use --group-ids here.
    aws ec2 describe-security-groups \
      --group-ids ${aws_security_group.rds.id} \
      --query "SecurityGroups[].IpPermissions"

    # 6.6 and 6.7 run ON the instance:
    aws ssm start-session --target ${aws_instance.app.id}
  EOT
}