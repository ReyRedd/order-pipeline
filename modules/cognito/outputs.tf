output "user_pool_id" {
  description = "Cognito User Pool ID - used by API Gateway authorizer"
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN - used by API Gateway authorizer"
  value       = aws_cognito_user_pool.this.arn
}

output "client_id" {
  description = "App client ID - used to authenticate and get JWT tokens"
  value       = aws_cognito_user_pool_client.this.id
}

output "endpoint" {
  description = "Cognito endpoint for token requests"
  value       = "https://cognito-idp.${var.environment == "dev" ? "us-east-1" : "us-east-1"}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}
