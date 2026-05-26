variable "function_name" { type = string }
variable "filename"      { type = string }
variable "source_hash"   { type = string }

variable "dynamodb_table_name" { type = string }
variable "dynamodb_table_arn"  { type = string }

variable "inventory_table_name" { type = string }
variable "inventory_table_arn"  { type = string }

variable "sqs_queue_arn" { type = string }
variable "dlq_arn"       { type = string }

variable "environment" {
  type    = string
  default = "dev"
}
