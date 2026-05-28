variable "name" {
  description = "Name prefix for all CloudWatch resources"
  type        = string
}

variable "ops_alerts_arn" {
  description = "SNS topic ARN for ops alerts"
  type        = string
}

variable "dlq_name" {
  description = "SQS DLQ name - used as CloudWatch dimension"
  type        = string
}

variable "queue_name" {
  description = "SQS main queue name - used in dashboard"
  type        = string
}

variable "processor_function_name" {
  description = "order_processor Lambda function name"
  type        = string
}

variable "intake_function_name" {
  description = "order_intake Lambda function name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix - used as CloudWatch dimension (e.g. app/my-alb/abc123)"
  type        = string
}

# ── Custom thresholds ─────────────────────────────────────────────────────────

variable "dlq_threshold" {
  description = "Number of DLQ messages that triggers an alarm"
  type        = number
  default     = 0   # any message in DLQ = alarm
}

variable "lambda_error_threshold" {
  description = "Number of Lambda errors per minute that triggers an alarm"
  type        = number
  default     = 0
}

variable "alb_5xx_threshold" {
  description = "Number of ALB 5xx errors per minute before alarming"
  type        = number
  default     = 5
}

variable "high_order_rate_threshold" {
  description = "Lambda invocations per minute considered a spike"
  type        = number
  default     = 100
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  description = "AWS region - required by CloudWatch dashboard widgets"
  type        = string
  default     = "us-east-1"
}
