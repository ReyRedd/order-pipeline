output "api_endpoint" {
  description = "POST /orders — serverless intake tier"
  value       = module.api_gateway.api_url
}

output "alb_endpoint" {
  description = "ALB DNS — EC2 worker tier"
  value       = "http://${module.alb.alb_dns_name}"
}

output "sqs_queue_url" {
  description = "SQS orders queue URL"
  value       = module.sqs.queue_url
}

output "dlq_url" {
  description = "Dead-letter queue — inspect failed messages here"
  value       = module.sqs.dlq_url
}

output "asg_name" {
  value = module.asg.asg_name
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "lambda_intake_log_group" {
  value = "/aws/lambda/${module.lambda.function_name}"
}

output "lambda_processor_log_group" {
  value = module.lambda_processor.log_group
}
