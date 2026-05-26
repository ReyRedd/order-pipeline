variable "api_name" {
  description = "Name of the API Gateway REST API"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda invoke ARN — used by API Gateway to call the function"
  type        = string
}

variable "lambda_arn" {
  description = "Lambda function ARN — used to grant invoke permission"
  type        = string
}

variable "environment" {
  description = "Deployment environment, used as the API Gateway stage name"
  type        = string
  default     = "dev"
}
