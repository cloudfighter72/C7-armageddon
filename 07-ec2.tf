############################################
# EC2 app host
############################################

resource "aws_instance" "app" {
  ami                         = local.ami_id
  instance_type               = var.ec2_instance_type
  key_name                    = var.aws_key_pair_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  # IMDSv2 only. With IMDSv1 any SSRF bug in the app can read the role's
  # temporary credentials straight out of the metadata service.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # user_data is stored in plaintext by AWS, so it carries only the secret's
  # *name*. The instance role resolves the actual credentials at runtime.
  # This is the "no passwords in code or AMIs" requirement from section 4.
  user_data = templatefile("${path.module}/user_data.sh", {
    region    = var.aws_region
    secret_id = aws_secretsmanager_secret.db.name
  })

  user_data_replace_on_change = true

  # Section 7: "App starts but DB fails - dependency order matters."
  # Without this the app can boot before the secret exists.
  depends_on = [
    aws_secretsmanager_secret_version.db,
    aws_iam_role_policy.ec2_secrets_read,
  ]

  tags = {
    Name = var.ec2_name
  }
}