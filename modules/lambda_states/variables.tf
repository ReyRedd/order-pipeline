variable "name"        { type = string }
variable "environment" {
  type    = string
  default = "dev"
}

# SQS
variable "sqs_queue_arn" { type = string }
variable "dlq_arn"       { type = string }

# Step Functions
variable "state_machine_arn" { type = string }

# DynamoDB
variable "orders_table_name"    { type = string }
variable "orders_table_arn"     { type = string }
variable "inventory_table_name" { type = string }
variable "inventory_table_arn"  { type = string }

# SNS
variable "sns_topic_arn" { type = string }

# Zip packages + hashes
variable "orchestrator_zip"       { type = string }
variable "orchestrator_hash"      { type = string }
variable "validate_zip"           { type = string }
variable "validate_hash"          { type = string }
variable "check_inventory_zip"    { type = string }
variable "check_inventory_hash"   { type = string }
variable "calculate_pricing_zip"  { type = string }
variable "calculate_pricing_hash" { type = string }
variable "fulfill_order_zip"      { type = string }
variable "fulfill_order_hash"     { type = string }
variable "handle_failure_zip"     { type = string }
variable "handle_failure_hash"    { type = string }
