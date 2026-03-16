variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "schedule_start" {
  description = "EventBridge cron to start EC2 (UTC). Empty to disable. Example: cron(0 13 ? * MON-FRI *) = 8 AM EST weekdays"
  type        = string
  default     = ""
}

variable "schedule_stop" {
  description = "EventBridge cron to stop EC2 (UTC). Empty to disable. Example: cron(0 1 ? * TUE-SAT *) = 8 PM EST weekdays"
  type        = string
  default     = ""
}

