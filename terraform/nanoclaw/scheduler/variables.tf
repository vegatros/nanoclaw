variable "instance_id" {
  description = "EC2 instance ID to start/stop"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "schedule_start" {
  description = "EventBridge cron expression for starting EC2 (UTC). Empty string disables. Example: cron(0 13 ? * MON-FRI *) = 8 AM EST weekdays"
  type        = string
  default     = ""
}

variable "schedule_stop" {
  description = "EventBridge cron expression for stopping EC2 (UTC). Empty string disables. Example: cron(0 1 ? * TUE-SAT *) = 8 PM EST weekdays"
  type        = string
  default     = ""
}
