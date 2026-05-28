################################################################################
# Dead-Letter Queue — catches messages that fail processing after max retries
################################################################################

resource "aws_sqs_queue" "dlq" {
  name                       = "${var.queue_name}-dlq"
  message_retention_seconds  = 1209600 # 14 days — gives you time to investigate

  tags = { Name = "${var.queue_name}-dlq" }
}

################################################################################
# Main Order Queue
################################################################################

resource "aws_sqs_queue" "orders" {
  name                       = var.queue_name
  visibility_timeout_seconds = 60  # must be >= Lambda timeout (30s) + buffer

  # After 3 failed processing attempts, move message to DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = var.queue_name }
}
