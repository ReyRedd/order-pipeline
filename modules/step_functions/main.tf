################################################################################
# IAM Role — Step Functions → Lambda
################################################################################

resource "aws_iam_role" "sfn_exec" {
  name = "${var.name}-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sfn_lambda_invoke" {
  name = "${var.name}-sfn-invoke-lambdas"
  role = aws_iam_role.sfn_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["lambda:InvokeFunction"]
      Resource = [
        var.validate_lambda_arn,
        var.check_inventory_lambda_arn,
        var.calculate_pricing_lambda_arn,
        var.fulfill_order_lambda_arn,
        var.handle_failure_lambda_arn,
      ]
    }]
  })
}

resource "aws_iam_role_policy" "sfn_logs" {
  name = "${var.name}-sfn-logs"
  role = aws_iam_role.sfn_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups",
      ]
      Resource = "*"
    }]
  })
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/${var.name}-order-processor"
  retention_in_days = 7
}

################################################################################
# Express State Machine
################################################################################

resource "aws_sfn_state_machine" "this" {
  name     = "${var.name}-order-processor"
  role_arn = aws_iam_role.sfn_exec.arn
  type     = "EXPRESS"

  definition = jsonencode({
    Comment = "Order processing pipeline — Phase 4"
    StartAt = "ValidateOrder"
    States = {

      ValidateOrder = {
        Type     = "Task"
        Resource = var.validate_lambda_arn
        Next     = "CheckInventory"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
          IntervalSeconds = 2
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "HandleFailure"
        }]
      }

      CheckInventory = {
        Type     = "Task"
        Resource = var.check_inventory_lambda_arn
        Next     = "CalculatePricing"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException"]
          IntervalSeconds = 2
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "HandleFailure"
        }]
      }

      CalculatePricing = {
        Type     = "Task"
        Resource = var.calculate_pricing_lambda_arn
        Next     = "FulfillOrder"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException"]
          IntervalSeconds = 2
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "HandleFailure"
        }]
      }

      FulfillOrder = {
        Type     = "Task"
        Resource = var.fulfill_order_lambda_arn
        Next     = "OrderCompleted"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException"]
          IntervalSeconds = 2
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "HandleFailure"
        }]
      }

      OrderCompleted = {
        Type = "Succeed"
      }

      HandleFailure = {
        Type     = "Task"
        Resource = var.handle_failure_lambda_arn
        End      = true
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException"]
          IntervalSeconds = 2
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tags = { Name = "${var.name}-order-processor" }
}