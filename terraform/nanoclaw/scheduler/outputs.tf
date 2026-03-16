output "start_lambda_arn" {
  description = "Start Lambda function ARN"
  value       = try(aws_lambda_function.start[0].arn, null)
}

output "stop_lambda_arn" {
  description = "Stop Lambda function ARN"
  value       = try(aws_lambda_function.stop[0].arn, null)
}
