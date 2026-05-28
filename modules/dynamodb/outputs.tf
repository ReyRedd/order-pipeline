output "table_name" {
  value = aws_dynamodb_table.orders.name
}

output "table_arn" {
  value = aws_dynamodb_table.orders.arn
}

output "inventory_table_name" {
  value = aws_dynamodb_table.inventory.name
}

output "inventory_table_arn" {
  value = aws_dynamodb_table.inventory.arn
}
