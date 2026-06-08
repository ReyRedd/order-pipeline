variable "name" {
  type = string
}

variable "validate_lambda_arn" {
  type = string
}

variable "check_inventory_lambda_arn" {
  type = string
}

variable "calculate_pricing_lambda_arn" {
  type = string
}

variable "fulfill_order_lambda_arn" {
  type = string
}

variable "handle_failure_lambda_arn" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}
