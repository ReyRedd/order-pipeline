################################################################################
# REST API — exposes POST /orders to the internet
################################################################################

resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "Order Processing API — Phase 1"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Creates the /orders path segment
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "orders"
}

# POST method on /orders (no auth for now — add Cognito in Phase 4)
resource "aws_api_gateway_method" "post_order" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "NONE"
}

# AWS_PROXY = pass the raw request straight to Lambda, return raw response
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.post_order.http_method
  integration_http_method = "POST"  # API GW → Lambda always uses POST internally
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# Deployment snapshot — triggers redeployment when the integration changes
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Must wait for the integration to exist before deploying
  depends_on = [aws_api_gateway_integration.lambda]

  lifecycle {
    create_before_destroy = true
  }
}

# Stage = a named version of the deployment (dev / staging / prod)
resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment


}

# NOTE: access_log_settings requires an account-level CloudWatch role
# (aws_api_gateway_account resource). Omitted here for simplicity —
# Lambda logs via CloudWatch are sufficient for Phase 1 debugging.

# Without this permission, API Gateway cannot invoke the Lambda function
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn
  principal     = "apigateway.amazonaws.com"

  # Scope to this specific API only — don't allow all of API Gateway
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
