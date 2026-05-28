variable "function_name" {
  type = string
}

variable "handler" {
  type    = string
  default = "handler.lambda_handler"
}

variable "runtime" {
  type    = string
  default = "python3.12"
}

variable "filename" {
  type = string
}

variable "source_hash" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "sqs_queue_url" {
  description = "Optional — SQS queue URL injected as SQS_QUEUE_URL env var"
  type        = string
  default     = ""
}

variable "sqs_queue_arn" {
  description = "Optional — SQS queue ARN used to grant SendMessage permission"
  type        = string
  default     = ""
}

variable "enable_sqs" {
  description = "Set to true to attach SQS publish permission and inject SQS_QUEUE_URL"
  type        = bool
  default     = false
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type = string
}
