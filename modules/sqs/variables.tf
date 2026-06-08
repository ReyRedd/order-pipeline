variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "environment" {
  type    = string
  default = "dev"
}
