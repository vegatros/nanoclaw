# NanoClaw Terraform Infrastructure

Deploys a fully automated NanoClaw instance on AWS. One `terraform apply` gives you a running Telegram bot with Claude-powered AI agent.

## Architecture

```
                         ┌─────────────────────────────────┐
                         │         AWS Cloud (us-east-1)    │
                         │                                  │
┌──────────┐             │  ┌────────────────────────────┐  │
│ Telegram │◄────────────┼──┤      EC2 (t3.small)       │  │
│   API    ├────────────►┼──┤                            │  │
└──────────┘             │  │  ┌──────────────────────┐  │  │
                         │  │  │  NanoClaw (systemd)  │  │  │
┌──────────┐             │  │  │                      │  │  │
│  Claude  │◄────────────┼──┤  │  ┌────────────────┐  │  │  │
│   API    ├────────────►┼──┤  │  │ Credential     │  │  │  │
└──────────┘             │  │  │  │ Proxy (:3001)  │  │  │  │
                         │  │  │  └────────────────┘  │  │  │
                         │  │  │                      │  │  │
                         │  │  │  ┌────────────────┐  │  │  │
                         │  │  │  │ Docker Agent   │  │  │  │
                         │  │  │  │ Containers     │  │  │  │
                         │  │  │  └────────────────┘  │  │  │
                         │  │  └──────────────────────┘  │  │
                         │  └────────────────────────────┘  │
                         │          │            ▲          │
                         │          │            │          │
                         │          ▼            │          │
                         │  ┌─────────────┐  ┌──────────┐  │
                         │  │   Secrets    │  │   IAM    │  │
                         │  │   Manager   │  │   Role   │  │
                         │  │             │  │          │  │
                         │  │ - Telegram  │  │ - SSM    │  │
                         │  │   Bot Token │  │ - Secrets│  │
                         │  │ - Claude    │  └──────────┘  │
                         │  │   OAuth     │                │
                         │  └─────────────┘                │
                         │                                  │
                         │  ┌────────────────────────────┐  │
                         │  │     VPC (10.10.0.0/16)     │  │
                         │  │  ┌──────────────────────┐  │  │
                         │  │  │  Public Subnet       │  │  │
                         │  │  │  Internet Gateway    │  │  │
                         │  │  │  Security Group      │  │  │
                         │  │  │  (egress only, no inbound)  │  │  │
                         │  │  └──────────────────────┘  │  │
                         │  └────────────────────────────┘  │
                         └─────────────────────────────────┘
```

## Resources Created

| Resource | Purpose |
|----------|---------|
| `aws_vpc` | Isolated network (10.10.0.0/16) |
| `aws_subnet` | Public subnet with auto-assign public IP |
| `aws_internet_gateway` | Internet access for the instance |
| `aws_route_table` | Routes traffic to the internet gateway |
| `aws_security_group` | Egress only (no inbound ports), access via SSM |
| `aws_iam_role` | EC2 role with SSM + Secrets Manager access |
| `aws_instance` | EC2 running pre-built NanoClaw AMI |

## External Dependencies (not managed by Terraform)

| Resource | Purpose |
|----------|---------|
| **AMI** (`nano-claw-setup-complete`) | Pre-built image with Docker, Node.js 22, Claude Code, NanoClaw, agent container, systemd service |
| **Secrets Manager** (`{project_name}/env`) | Stores `TELEGRAM_BOT_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN` |
| **S3 Backend** (`terraform-state-925185632967`) | Remote state storage |

## Boot Sequence

1. EC2 launches from pre-built AMI
2. `user_data` script runs:
   - Enables `loginctl linger` for ec2-user (service survives logout)
   - Waits for IAM instance profile to propagate
   - Pulls tokens from Secrets Manager
   - Writes `/home/ec2-user/nanoclaw/.env`
   - Starts `nanoclaw.service` via systemd
3. NanoClaw connects to Telegram and begins processing messages

## Usage

### Prerequisites

1. Create the secret (one-time):
   ```bash
   aws secretsmanager create-secret \
     --name "nanoclaw-dev/env" \
     --region us-east-1 \
     --secret-string '{"TELEGRAM_BOT_TOKEN":"your-token","CLAUDE_CODE_OAUTH_TOKEN":"your-token"}'
   ```

2. Ensure the AMI `nano-claw-setup-complete` exists in your account.

### Deploy

```bash
cd terraform/nanoclaw
terraform init
terraform apply -var-file=vars/dev.tfvars
```

### Destroy and Rebuild

```bash
terraform destroy -var-file=vars/dev.tfvars
terraform apply -var-file=vars/dev.tfvars
```

Secrets persist in Secrets Manager across destroy/apply cycles.

### Connect via SSM

```bash
aws ssm start-session --target $(terraform output -raw instance_id) --region us-east-1
```

### Update Tokens

```bash
aws secretsmanager update-secret \
  --secret-id "nanoclaw-dev/env" \
  --region us-east-1 \
  --secret-string '{"TELEGRAM_BOT_TOKEN":"new-token","CLAUDE_CODE_OAUTH_TOKEN":"new-token"}'
```

Then restart the service on the instance:
```bash
systemctl --user restart nanoclaw
```

## Environments

| File | Project Name | Instance Type |
|------|-------------|---------------|
| `vars/dev.tfvars` | nanoclaw-dev | t3.small |
| `vars/qa.tfvars` | nanoclaw-qa | t3.small |
| `vars/prod.tfvars` | nanoclaw-prod | t3.small |

## File Structure

```
terraform/nanoclaw/
├── main.tf                 # VPC, SG, IAM, EC2 instance
├── variables.tf            # Input variables
├── outputs.tf              # instance_id, public_ip, ssm_command
├── providers.tf            # AWS provider with default tags
├── versions.tf             # Terraform >= 1.0, AWS ~> 5.0
├── backend.tf              # S3 remote state
├── .terraform.lock.hcl     # Provider lock file
├── .gitignore              # Excludes .terraform/ and state files
├── vars/
│   ├── dev.tfvars
│   ├── qa.tfvars
│   └── prod.tfvars
└── container/
    ├── Dockerfile          # Agent container overlay
    └── server.mjs          # HTTP wrapper for agent execution
```
