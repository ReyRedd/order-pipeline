output "queue_url" {
  description = "SQS queue URL - passed to order_intake Lambda as env var"
  value       = aws_sqs_queue.orders.url
}

output "queue_arn" {
  description = "SQS queue ARN - used for IAM permissions and event source mapping"
  value       = aws_sqs_queue.orders.arn
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "queue_name" {
  value = aws_sqs_queue.orders.name
}

output "dlq_name" {
  value = aws_sqs_queue.dlq.name
}
