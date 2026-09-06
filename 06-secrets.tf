############################################
# Master password
############################################

# Generated rather than typed into terraform.tfvars, so no live credential
# is ever committed. It is still written to state, so keep the state bucket
# encrypted and private.
resource "random_password" "db" {
  length  = 24
  special = true

  # RDS rejects /, " and @ in a master password.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

############################################
# Secrets Manager
############################################

resource "aws_secretsmanager_secret" "db" {
  name        = var.secret_name
  description = "MySQL credentials for the EC2 to RDS lab"

  # 0 deletes immediately on destroy, so the lab can be torn down and
  # rebuilt under the same secret name without a 7-day wait.
  recovery_window_in_days = 0

  tags = {
    Name = "lab-rds-credentials"
  }
}

# The key names here are exactly what section 6.6 expects to see:
# username, password, host, port.
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    engine   = "mysql"
  })
}