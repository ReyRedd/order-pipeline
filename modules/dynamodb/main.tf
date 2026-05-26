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

# Inventory table — tracks stock levels per item
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

# Seed inventory with sample products on every apply
# (only writes if the item doesn't already exist — idempotent)
resource "aws_dynamodb_table_item" "inventory_seed" {
  for_each   = var.inventory_seed
  table_name = aws_dynamodb_table.inventory.name
  hash_key   = aws_dynamodb_table.inventory.hash_key

  item = jsonencode({
    item_name   = { S = each.key }
    stock       = { N = tostring(each.value.stock) }
    price       = { N = tostring(each.value.price) }
    description = { S = each.value.description }
  })

  lifecycle {
    # Don't overwrite stock if it was decremented by real orders
    ignore_changes = [item]
  }
}
