output "state_machine_arn" {
  description = "State machine ARN - passed to orchestrator Lambda as env var"
  value       = aws_sfn_state_machine.this.arn
}

output "state_machine_name" {
  value = aws_sfn_state_machine.this.name
}

output "log_group" {
  value = aws_cloudwatch_log_group.sfn_logs.name
}
