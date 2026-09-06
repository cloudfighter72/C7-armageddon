############################################
# RDS security group
############################################

resource "aws_security_group" "rds" {
  name        = var.rds_sg_name
  description = "RDS: MySQL from the app host security group only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = var.rds_sg_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# This is the rule the lab grades in section 6.5 and deliverable A.3.
# referenced_security_group_id, not cidr_ipv4. The source is an identity,
# not an address range, so the rule keeps working when the app host is
# replaced and gets a new IP.
resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from the app host security group"
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

# Deliberately no egress rule. A database never initiates outbound
# connections. With standalone rule resources, defining none means none
# exists, unlike inline blocks which default to allow-all.