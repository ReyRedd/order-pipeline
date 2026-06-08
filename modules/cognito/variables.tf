variable "name" {
  description = "Name prefix for Cognito resources"
  type        = string
}

variable "environment" {
  type    = string
  default = "dev"
}
