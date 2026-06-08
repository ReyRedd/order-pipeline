"""
State 2: CheckInventory
=======================
Verifies stock availability for every item in the order.
Input:  order object from Step Functions
Output: order object enriched with inventory_snapshot
Raises: BusinessRuleError if any item is out of stock
"""

import boto3
import os

dynamodb        = boto3.resource("dynamodb")
inventory_table = dynamodb.Table(os.environ["INVENTORY_TABLE"])


def lambda_handler(event, _context):
    order    = event
    items    = order["items"]
    snapshot = {}

    for item in items:
        name       = item["name"]
        qty_needed = int(item["qty"])

        response = inventory_table.get_item(Key={"item_name": name})
        record   = response.get("Item")

        if not record:
            raise BusinessRuleError(
                f"Item '{name}' not found in inventory catalogue"
            )

        stock = int(record["stock"])
        snapshot[name] = {"available": stock, "requested": qty_needed}

        if stock < qty_needed:
            raise BusinessRuleError(
                f"Insufficient stock for '{name}': "
                f"requested {qty_needed}, available {stock}"
            )

    print(f"[{order['order_id']}] Inventory check passed: {snapshot}")

    # Enrich the order with the inventory snapshot and pass to next state
    return {**order, "inventory_snapshot": snapshot}


class BusinessRuleError(Exception):
    pass
