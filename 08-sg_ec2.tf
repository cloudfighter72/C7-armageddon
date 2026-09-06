############################################
# EC2 app host security group
############################################

resource "aws_security_group" "ec2" {
  name        = var.ec2_sg_name
  description = "App host: HTTP from allowed CIDRs, SSH from admin CIDRs"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = var.ec2_sg_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  for_each = toset(var.http_ingress_cidrs)

  security_group_id = aws_security_group.ec2.id
  description       = "HTTP to the notes app from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  for_each = toset(var.ssh_ingress_cidrs)

  security_group_id = aws_security_group.ec2.id
  description       = "SSH from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  description       = "All outbound: RDS, Secrets Manager, package repos"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}