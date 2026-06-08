################################################################################
# Shared IAM helper - creates a Lambda role with custom policies
################################################################################

locals {
  common_env = {
    ENVIRONMENT = var.environment
  }
}

# ── Orchestrator ──────────────────────────────────────────────────────────────

resource "aws_iam_role" "orchestrator" {
  name = "${var.name}-orchestrator-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "orchestrator_logs" {
  role       = aws_iam_role.orchestrator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "orchestrator_sfn" {
  name = "${var.name}-orchestrator-sfn"
  role = aws_iam_role.orchestrator.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["states:StartExecution"], Resource = var.state_machine_arn }]
  })
}

resource "aws_iam_role_policy" "orchestrator_sqs" {
  name = "${var.name}-orchestrator-sqs"
  role = aws_iam_role.orchestrator.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = [var.sqs_queue_arn, var.dlq_arn] }]
  })
}

resource "aws_lambda_function" "orchestrator" {
  function_name    = "${var.name}-orchestrator"
  role             = aws_iam_role.orchestrator.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = var.orchestrator_zip
  source_code_hash = var.orchestrator_hash
  timeout          = 30
  memory_size      = 128
  environment { variables = merge(local.common_env, { STATE_MACHINE_ARN = var.state_machine_arn }) }
}

resource "aws_cloudwatch_log_group" "orchestrator" {
  name              = "/aws/lambda/${aws_lambda_function.orchestrator.function_name}"
  retention_in_days = 7
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.orchestrator.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 20
  enabled                            = true
}

# ── State: ValidateOrder ──────────────────────────────────────────────────────

resource "aws_iam_role" "validate" {
  name = "${var.name}-validate-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "validate_logs" {
  role       = aws_iam_role.validate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_lambda_function" "validate" {
  function_name    = "${var.name}-validate-order"
  role             = aws_iam_role.validate.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = var.validate_zip
  source_code_hash = var.validate_hash
  timeout          = 30
  memory_size      = 128
  environment { variables = local.common_env }
}
resource "aws_cloudwatch_log_group" "validate" {
  name              = "/aws/lambda/${aws_lambda_function.validate.function_name}"
  retention_in_days = 7
}

# ── State: CheckInventory ─────────────────────────────────────────────────────

resource "aws_iam_role" "check_inventory" {
  name = "${var.name}-check-inventory-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "check_inventory_logs" {
  role       = aws_iam_role.check_inventory.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "check_inventory_dynamo" {
  name = "${var.name}-check-inventory-dynamo"
  role = aws_iam_role.check_inventory.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = var.inventory_table_arn }]
  })
}
resource "aws_lambda_function" "check_inventory" {
  function_name    = "${var.name}-check-inventory"
  role             = aws_iam_role.check_inventory.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = var.check_inventory_zip
  source_code_hash = var.check_inventory_hash
  timeout          = 30
  memory_size      = 128
  environment { variables = merge(local.common_env, { INVENTORY_TABLE = var.inventory_table_name }) }
}
resource "aws_cloudwatch_log_group" "check_inventory" {
  name              = "/aws/lambda/${aws_lambda_function.check_inventory.function_name}"
  retention_in_days = 7
}

# ── State: CalculatePricing ───────────────────────────────────────────────────

resource "aws_iam_role" "calculate_pricing" {
  name = "${var.name}-calculate-pricing-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "calculate_pricing_logs" {
  role       = aws_iam_role.calculate_pricing.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_lambda_function" "calculate_pricing" {
  function_name    = "${var.name}-calculate-pricing"
  role             = aws_iam_role.calculate_pricing.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = var.calculate_pricing_zip
  source_code_hash = var.calculate_pricing_hash
  timeout          = 30
  memory_size      = 128
  environment { variables = local.common_env }
}
resource "aws_cloudwatch_log_group" "calculate_pricing" {
  name              = "/aws/lambda/${aws_lambda_function.calculate_pricing.function_name}"
  retention_in_days = 7
}

# ── State: FulfillOrder ───────────────────────────────────────────────────────

resource "aws_iam_role" "fulfill_order" {
  name = "${var.name}-fulfill-order-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "fulfill_order_logs" {
  role       = aws_iam_role.fulfill_order.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "fulfill_order_access" {
  name = "${var.name}-fulfill-order-access"
  role = aws_iam_role.fulfill_order.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = var.orders_table_arn },
      { Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = var.inventory_table_arn },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = var.sns_topic_arn },
    ]
  })
}
resource "aws_lambda_function" "fulfill_order" {
  function_name    = "${var.name}-fulfill-order"
  role             = aws_iam_role.fulfill_order.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = var.fulfill_order_zip
  source_code_hash = var.fulfill_order_hash
  timeout          = 30
  memory_size      = 128
  environment {
    variables = merge(local.common_env, {
      DYNAMODB_TABLE  = var.orders_table_name
      INVENTORY_TABLE = var.inventory_table_name
      SNS_TOPIC_ARN   = var.sns_topic_arn
    })
  }
}
resource "aws_cloudwatch_log_group" "fulfill_order" {
  name              = "/aws/lambda/${aws_lambda_function.fulfill_order.function_name}"
  retention_in_days = 7
}

# ── State: HandleFailure ──────────────────────────────────────────────────────

resource "aws_iam_role" "handle_failure" {
  name = "${var.name}-handle-failure-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "handle_failure_logs" {
  role       = aws_iam_role.handle_failure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "handle_failure_access" {
  name = "${var.name}-handle-failure-access"
  role = aws_iam_role.handle_failure.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = var.orders_table_arn },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = var.sns_topic_arn },
    ]
  })
}
resource "aws_lambda_function" "handle_failure" {
  function_name    = "${var.name}-handle-failure"
  role             = aws_iam_role.handle_failure.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = var.handle_failure_zip
  source_code_hash = var.handle_failure_hash
  timeout          = 30
  memory_size      = 128
  environment {
    variables = merge(local.common_env, {
      DYNAMODB_TABLE = var.orders_table_name
      SNS_TOPIC_ARN  = var.sns_topic_arn
    })
  }
}
resource "aws_cloudwatch_log_group" "handle_failure" {
  name              = "/aws/lambda/${aws_lambda_function.handle_failure.function_name}"
  retention_in_days = 7
}
