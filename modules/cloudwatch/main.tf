# CloudWatch Alarms - Phase 3
################################################################################

# ── 1. DLQ depth alarm ───────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.name}-dlq-messages"
  alarm_description   = "Orders are landing in the Dead-Letter Queue - processing failures need investigation"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = var.dlq_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = var.dlq_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.ops_alerts_arn]
  ok_actions          = [var.ops_alerts_arn]
  tags                = { Name = "${var.name}-dlq-messages" }
}

# ── 2. Lambda processor errors ───────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name}-processor-errors"
  alarm_description   = "order_processor Lambda is throwing errors - check CloudWatch logs"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = var.processor_function_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = var.lambda_error_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.ops_alerts_arn]
  ok_actions          = [var.ops_alerts_arn]
  tags                = { Name = "${var.name}-processor-errors" }
}

# ── 3. ALB 5xx errors ────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB is returning 5xx errors - EC2 worker tier may be unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.ops_alerts_arn]
  ok_actions          = [var.ops_alerts_arn]
  tags                = { Name = "${var.name}-alb-5xx" }
}

# ── 4. High order rate ────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "high_order_rate" {
  alarm_name          = "${var.name}-high-order-rate"
  alarm_description   = "Unusually high order intake rate - possible traffic spike or abuse"
  namespace           = "AWS/Lambda"
  metric_name         = "Invocations"
  dimensions          = { FunctionName = var.intake_function_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.high_order_rate_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.ops_alerts_arn]
  ok_actions          = [var.ops_alerts_arn]
  tags                = { Name = "${var.name}-high-order-rate" }
}

# ── 5. Lambda processor duration ─────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "processor_duration" {
  alarm_name          = "${var.name}-processor-slow"
  alarm_description   = "order_processor is running slow - approaching Lambda timeout"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  dimensions          = { FunctionName = var.processor_function_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 20000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.ops_alerts_arn]
  ok_actions          = [var.ops_alerts_arn]
  tags                = { Name = "${var.name}-processor-slow" }
}


# CloudWatch Dashboard
################################################################################

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Order Intake - Lambda Invocations"
          region  = var.aws_region
          metrics = [["AWS/Lambda", "Invocations", "FunctionName", var.intake_function_name]]
          period  = 60
          stat    = "Sum"
          view    = "timeSeries"
          annotations = { horizontal = [] }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Order Processor - Errors & Duration"
          region  = var.aws_region
          metrics = [
            ["AWS/Lambda", "Errors",   "FunctionName", var.processor_function_name],
            ["AWS/Lambda", "Duration", "FunctionName", var.processor_function_name]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          annotations = { horizontal = [] }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "SQS — Queue Depth & DLQ"
          region  = var.aws_region
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.queue_name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          annotations = { horizontal = [] }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB - Request Count & 5xx Errors"
          region  = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",              "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          annotations = { horizontal = [] }
        }
      }
    ]
  })
}
