variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  type    = string
  default = "order-pipeline"
}

# ── Phase 3: Notifications ────────────────────────────────────────────────────

variable "notification_email" {
  description = "Email that receives order confirmations and ops alerts. Set this before deploying."
  type        = string
  default     = "reynoldmwakio@gmail.com"   # ← CHANGE THIS before terraform apply
}

# ── Phase 3: Custom alarm thresholds ─────────────────────────────────────────

variable "dlq_threshold" {
  description = "DLQ message count that triggers an alarm (default: any message)"
  type        = number
  default     = 0
}

variable "lambda_error_threshold" {
  description = "Lambda error count per minute before alarming"
  type        = number
  default     = 0
}

variable "alb_5xx_threshold" {
  description = "ALB 5xx errors per minute before alarming"
  type        = number
  default     = 5
}

variable "high_order_rate_threshold" {
  description = "Lambda invocations per minute considered a traffic spike"
  type        = number
  default     = 100
}
