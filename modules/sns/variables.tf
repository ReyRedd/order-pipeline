variable "name" {
  description = "Name prefix for SNS topics"
  type        = string
}

variable "notification_email" {
  description = "Email address that receives order notifications and ops alerts"
  type        = string
}

variable "environment" {
  type    = string
  default = "dev"
}
