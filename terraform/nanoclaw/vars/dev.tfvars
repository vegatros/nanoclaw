environment         = "dev"
project_name        = "nanoclaw-dev"
aws_region          = "us-east-1"
vpc_cidr            = "10.10.0.0/16"
public_subnet_cidrs = ["10.10.1.0/24"]
instance_type       = "t3.small"
schedule_start      = "cron(0 13 ? * * *)"  # 9 AM EDT daily
schedule_stop       = "cron(0 5 ? * * *)"   # 1 AM EDT daily
