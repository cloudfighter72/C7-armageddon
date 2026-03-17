output "application_urls" {
  description = "URLs to test deployed application"
  value       = <<EOT

  Home:           http://${aws_instance.lab_ec2.public_ip}/
  Initialize DB:  http://${aws_instance.lab_ec2.public_ip}/init
  1st note (GET): http://${aws_instance.lab_ec2.public_ip}/add?note=first_note
  2nd note (GET): http://${aws_instance.lab_ec2.public_ip}/add?note=blue_book_gentlemen
  3rd note (GET): http://${aws_instance.lab_ec2.public_ip}/add?note=this_is_200k_work
  4th note (GET): http://${aws_instance.lab_ec2.public_ip}/add?note=a_passport_is_freedom_papers
  5th note (GET): http://${aws_instance.lab_ec2.public_ip}/add?note=lab_1c_is_a_success
  List notes:     http://${aws_instance.lab_ec2.public_ip}/list
  EOT
}

# Explanation: Outputs are your mission report—what got built and where to find it.
output "vpc_id" {
  value = aws_vpc.lab_1c_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

output "ec2_instance" {
  value = aws_instance.lab_ec2.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.rds_db.address
}

output "sns_topic_arn" {
  value = aws_sns_topic.db_alarm.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.lab_1c_lg.name
}