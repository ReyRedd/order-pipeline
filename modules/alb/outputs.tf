output "alb_dns_name" {
  description = "Public DNS name of the ALB - use this to reach your EC2 app"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "target_group_arn" {
  description = "ARN passed to the ASG so it registers instances automatically"
  value       = aws_lb_target_group.this.arn
}

output "alb_sg_id" {
  description = "ALB security group ID - EC2 instances must allow inbound from this"
  value       = aws_security_group.alb.id
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used as CloudWatch dimension"
  value       = aws_lb.this.arn_suffix
}
