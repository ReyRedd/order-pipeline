output "validate_arn"           { value = aws_lambda_function.validate.arn }
output "check_inventory_arn"    { value = aws_lambda_function.check_inventory.arn }
output "calculate_pricing_arn"  { value = aws_lambda_function.calculate_pricing.arn }
output "fulfill_order_arn"      { value = aws_lambda_function.fulfill_order.arn }
output "handle_failure_arn"     { value = aws_lambda_function.handle_failure.arn }
output "orchestrator_name"      { value = aws_lambda_function.orchestrator.function_name }
