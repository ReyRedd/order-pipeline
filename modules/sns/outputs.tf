output "order_notifications_arn" {
  description = "SNS topic ARN for order notifications — passed to order_processor Lambda"
  value       = aws_sns_topic.order_notifications.arn
}

output "ops_alerts_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = aws_sns_topic.ops_alerts.arn
}
