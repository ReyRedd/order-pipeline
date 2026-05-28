################################################################################
# SNS Topic — Order Notifications (customer-facing)
# Sends COMPLETED / FAILED emails to the customer
################################################################################

resource "aws_sns_topic" "order_notifications" {
  name = "${var.name}-order-notifications"
  tags = { Name = "${var.name}-order-notifications" }
}

# Email subscription — customer inbox
# ⚠️ AWS sends a confirmation email to this address on first deploy.
#    The subscription stays PENDING until the link is clicked.
resource "aws_sns_topic_subscription" "order_email" {
  topic_arn = aws_sns_topic.order_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

################################################################################
# SNS Topic — Ops Alerts (internal)
# Receives CloudWatch alarm notifications
################################################################################

resource "aws_sns_topic" "ops_alerts" {
  name = "${var.name}-ops-alerts"
  tags = { Name = "${var.name}-ops-alerts" }
}

resource "aws_sns_topic_subscription" "ops_email" {
  topic_arn = aws_sns_topic.ops_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
