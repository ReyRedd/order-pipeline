resource "aws_iam_role" "processor_exec" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.processor_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.function_name}-dynamodb"
  role = aws_iam_role.processor_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Orders table — read and update status + enriched fields
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = var.dynamodb_table_arn
      },
      {
        # Inventory table — read stock + atomically decrement
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = var.inventory_table_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "sqs_consume" {
  name = "${var.function_name}-sqs"
  role = aws_iam_role.processor_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = [var.sqs_queue_arn, var.dlq_arn]
    }]
  })
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.processor_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = var.filename
  source_code_hash = var.source_hash
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE  = var.dynamodb_table_name
      INVENTORY_TABLE = var.inventory_table_name
      ENVIRONMENT     = var.environment
    }
  }
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.this.arn
  batch_size                         = 10
  enabled                            = true
  maximum_batching_window_in_seconds = 20
}
