variable "name" {
  description = "Name prefix for all ALB resources"
  type        = string
}

variable "instance_port" {
  description = "Port the EC2 instances are listening on"
  type        = number
  default     = 8080
}

variable "environment" {
  type    = string
  default = "dev"
}
