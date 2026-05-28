# Orders table
resource "aws_dynamodb_table" "orders" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  deletion_protection_enabled = false
  tags = { Name = var.table_name }
}

# Inventory table
resource "aws_dynamodb_table" "inventory" {
  name         = "${var.table_name}-inventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "item_name"

  attribute {
    name = "item_name"
    type = "S"
  }

  deletion_protection_enabled = false
  tags = { Name = "${var.table_name}-inventory" }
}