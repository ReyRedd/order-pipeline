output "api_endpoint" {
  description = "POST /orders - requires Authorization: Bearer <jwt_token>"
  value       = module.api_gateway.api_url
}

output "cognito_user_pool_id" {
  description = "Used to create users and get JWT tokens"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "App client ID - needed for authentication requests"
  value       = module.cognito.client_id
}

output "state_machine_arn" {
  value = module.step_functions.state_machine_arn
}

output "alb_endpoint"               { value = "http://${module.alb.alb_dns_name}" }
output "sqs_queue_url"              { value = module.sqs.queue_url }
output "dlq_url"                    { value = module.sqs.dlq_url }
output "dynamodb_table_name"        { value = module.dynamodb.table_name }
output "cloudwatch_dashboard"       { value = module.cloudwatch.dashboard_url }
output "lambda_intake_log_group"    { value = "/aws/lambda/${module.lambda.function_name}" }
output "step_functions_log_group"   { value = module.step_functions.log_group }
