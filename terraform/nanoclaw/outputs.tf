output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.nanoclaw.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.nanoclaw.public_ip
}

output "ssm_command" {
  description = "SSM command to connect"
  value       = "aws ssm start-session --target ${aws_instance.nanoclaw.id} --region ${var.aws_region}"
}
