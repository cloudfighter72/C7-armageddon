############################################
# IAM role for the EC2 app host
############################################

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "lab-ec2-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "lab-ec2-app-role"
  }
}

# Lets you open a shell with `aws ssm start-session` without opening port 22
# at all. Useful for the section 6.6 and 6.7 checks if you did not set a key
# pair, or if your IP changed.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

############################################
# Least privilege: one secret, read only
############################################

# The lab grades "Least Privilege: prevents credential leakage and lateral
# movement." The managed SecretsManagerReadWrite policy would grant read AND
# write on every secret in the account. This grants read on exactly one.
data "aws_iam_policy_document" "ec2_secrets_read" {
  statement {
    sid    = "ReadLabDatabaseSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [aws_secretsmanager_secret.db.arn]
  }
}

resource "aws_iam_role_policy" "ec2_secrets_read" {
  name   = "lab-secrets-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_secrets_read.json
}

############################################
# Instance profile
############################################

# Section 6.2 checks that this ARN comes back non-null.
resource "aws_iam_instance_profile" "ec2" {
  name = "lab-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "lab-ec2-instance-profile"
  }
}