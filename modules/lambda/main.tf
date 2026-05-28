################################################################################
# IAM — who can run this Lambda, and what can it touch?
################################################################################

resource "aws_iam_role" "lambda_exec" {
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
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.function_name}-dynamodb"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      Resource = var.dynamodb_table_arn
    }]
  })
}

# Optional — only attached when enable_sqs = true
resource "aws_iam_role_policy" "sqs_publish" {
  count = var.enable_sqs ? 1 : 0
  name  = "${var.function_name}-sqs"
  role  = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = var.sqs_queue_arn
    }]
  })
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = var.filename
  source_code_hash = var.source_hash
  timeout          = 30
  memory_size      = 128

  environment {
    variables = merge(
      {
        DYNAMODB_TABLE = var.dynamodb_table_name
        ENVIRONMENT    = var.environment
      },
      # Only inject SQS_QUEUE_URL when provided
      var.sqs_queue_url != "" ? { SQS_QUEUE_URL = var.sqs_queue_url } : {}
    )
  }
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
}
