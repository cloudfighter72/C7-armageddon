############################################
# RDS subnet group
############################################

resource "aws_db_subnet_group" "main" {
  name       = "lab-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "lab-rds-subnet-group"
  }
}

############################################
# RDS MySQL instance
############################################

resource "aws_db_instance" "main" {
  identifier     = var.db_identifier
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Deliverable A.2 and the security model in section 4: the database is
  # not reachable from the internet.
  publicly_accessible = false

  multi_az                   = false
  backup_retention_period    = 0
  auto_minor_version_upgrade = true
  skip_final_snapshot        = true
  deletion_protection        = false
  apply_immediately          = true

  tags = {
    Name = var.db_identifier
  }

  lifecycle {
    # The live password is in Secrets Manager. Ignoring it here means a
    # manual rotation does not show up as permanent Terraform drift.
    ignore_changes = [password]
  }
}