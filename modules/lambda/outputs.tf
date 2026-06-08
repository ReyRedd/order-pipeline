output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

# invoke_arn is what API Gateway uses - different from the regular ARN
output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}
