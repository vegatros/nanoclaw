output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.nanoclaw.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.nanoclaw.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = var.key_name != "" ? "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.nanoclaw.public_ip}" : "Use SSM: aws ssm start-session --target ${aws_instance.nanoclaw.id}"
}
