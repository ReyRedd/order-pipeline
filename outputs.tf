output "api_endpoint" {
  value = module.api_gateway.api_url
}

output "alb_endpoint" {
  value = "http://${module.alb.alb_dns_name}"
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "dlq_url" {
  value = module.sqs.dlq_url
}

output "cloudwatch_dashboard" {
  description = "Open this URL to view the monitoring dashboard"
  value       = module.cloudwatch.dashboard_url
}

output "asg_name"                  { value = module.asg.asg_name }
output "dynamodb_table_name"       { value = module.dynamodb.table_name }
output "lambda_intake_log_group"   { value = "/aws/lambda/${module.lambda.function_name}" }
output "lambda_processor_log_group"{ value = module.lambda_processor.log_group }
