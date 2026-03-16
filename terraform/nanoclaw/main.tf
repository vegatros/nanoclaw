# Admin role for managing NanoClaw infrastructure (assumable by any IAM principal in this account)
resource "aws_iam_role" "admin" {
  name = "nanoclaw-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::925185632967:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "admin" {
  name = "nanoclaw-management"
  role = aws_iam_role.admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EC2Full"
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
      {
        Sid    = "IAMRolesAndProfiles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole",
          "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile", "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile", "iam:UntagInstanceProfile"
        ]
        Resource = [
          "arn:aws:iam::925185632967:role/nanoclaw-*",
          "arn:aws:iam::925185632967:instance-profile/nanoclaw-*"
        ]
      },
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:UpdateSecret",
          "secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue",
          "secretsmanager:TagResource"
        ]
        Resource = "arn:aws:secretsmanager:us-east-1:925185632967:secret:nanoclaw-*"
      },
      {
        Sid    = "SSM"
        Effect = "Allow"
        Action = [
          "ssm:StartSession", "ssm:TerminateSession",
          "ssm:SendCommand", "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformStateS3"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::terraform-state-925185632967",
          "arn:aws:s3:::terraform-state-925185632967/*"
        ]
      },
      {
        Sid      = "TerraformStateDynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:us-east-1:925185632967:table/terraform-state-lock"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      }
    ]
  })
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_availability_zones" "available" { state = "available" }

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "nanoclaw" {
  name        = "${var.project_name}-sg"
  description = "Security group for nanoclaw EC2"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role with SSM access
resource "aws_iam_role" "nanoclaw" {
  name = "${var.project_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nanoclaw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "secrets" {
  name = "${var.project_name}-secrets"
  role = aws_iam_role.nanoclaw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [data.aws_secretsmanager_secret.nanoclaw.arn]
    }]
  })
}

resource "aws_iam_instance_profile" "nanoclaw" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.nanoclaw.name
}

# Secrets Manager for tokens (created and managed outside Terraform via AWS CLI)
# Create: aws secretsmanager create-secret --name "nanoclaw-dev/env" --secret-string '{"TELEGRAM_BOT_TOKEN":"...","CLAUDE_CODE_OAUTH_TOKEN":"..."}'
# Update: aws secretsmanager update-secret --secret-id "nanoclaw-dev/env" --secret-string '{"TELEGRAM_BOT_TOKEN":"...","CLAUDE_CODE_OAUTH_TOKEN":"..."}'
data "aws_secretsmanager_secret" "nanoclaw" {
  name = "${var.project_name}/env"
}

# NanoClaw pre-built AMI (includes Docker, Node.js 22, Claude Code, nanoclaw built, agent container image, systemd service, linger enabled)
data "aws_ami" "nanoclaw" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["nano-claw-setup-complete"]
  }
}

# EC2 Instance
resource "aws_instance" "nanoclaw" {
  ami                    = data.aws_ami.nanoclaw.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nanoclaw.id]
  iam_instance_profile   = aws_iam_instance_profile.nanoclaw.name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Enable lingering so systemd user services survive session logout
    loginctl enable-linger ec2-user

    # Wait for IAM instance profile to propagate
    for i in $(seq 1 30); do
      aws sts get-caller-identity --region ${var.aws_region} >/dev/null 2>&1 && break
      sleep 2
    done

    # Pull secrets from Secrets Manager and write .env
    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "${var.project_name}/env" \
      --region "${var.aws_region}" \
      --query SecretString --output text)

    ENV_FILE=/home/ec2-user/nanoclaw/.env
    echo "$SECRET" | python3 -c "
    import sys, json
    for k, v in json.load(sys.stdin).items():
        if v: print(f'{k}={v}')
    " > "$ENV_FILE"
    chown ec2-user:ec2-user "$ENV_FILE"
    chmod 600 "$ENV_FILE"

    # Start the service
    su - ec2-user -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user start nanoclaw.service'
  EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }

  depends_on = [data.aws_secretsmanager_secret.nanoclaw]
}
