variable "name" {
  description = "Name prefix for all ASG resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type — t3.micro is free-tier eligible"
  type        = string
  default     = "t3.micro"
}

variable "instance_port" {
  description = "Port the app on EC2 listens on — must match ALB target group"
  type        = number
  default     = 8080
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances the ASG can scale to"
  type        = number
  default     = 4
}

variable "desired_size" {
  description = "Target number of running instances"
  type        = number
  default     = 2
}

variable "target_group_arn" {
  description = "ALB target group ARN — instances register here automatically"
  type        = string
}

variable "alb_sg_id" {
  description = "ALB security group ID — EC2 allows inbound only from this"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EC2 instances will be launched"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to spread instances across — use multiple AZs"
  type        = list(string)
}

variable "environment" {
  type    = string
  default = "dev"
}
