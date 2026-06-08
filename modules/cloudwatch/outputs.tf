output "dashboard_name" {
  description = "CloudWatch dashboard name — open this in the AWS console"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
