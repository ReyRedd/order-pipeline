output "api_url" {
  description = "Full URL for the POST /orders endpoint"
  value       = "${aws_api_gateway_stage.this.invoke_url}/orders"
}

output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.this.id
}
