"""
State 4: FulfillOrder
=====================
Final step — commits inventory, updates DynamoDB to COMPLETED, sends SNS email.
Input:  enriched order object (with pricing from State 3)
Output: order_id (execution complete)
"""

import json
import boto3
import os
from datetime import datetime, timezone, timedelta

dynamodb        = boto3.resource("dynamodb")
sns             = boto3.client("sns")
orders_table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
inventory_table = dynamodb.Table(os.environ["INVENTORY_TABLE"])
SNS_TOPIC_ARN   = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, _context):
    order    = event
    order_id = order["order_id"]
    pricing  = order["pricing"]
    items    = order["items"]

    # Step 1 - atomically commit inventory
    _commit_inventory(items, order_id)

    # Step 2 - calculate estimated delivery date
    delivery_days = int(pricing["delivery_days"])
    eta = (datetime.now(timezone.utc) + timedelta(days=delivery_days)).strftime("%Y-%m-%d")

    # Step 3 - update order to COMPLETED with all enriched fields
    _update_order(order_id, {
        "status":             "COMPLETED",
        "subtotal":           pricing["subtotal"],
        "discount_applied":   pricing["discount_applied"],
        "shipping_cost":      pricing["shipping_cost"],
        "final_total":        pricing["final_total"],
        "estimated_delivery": eta,
        "completed_at":       _now(),
    })

    # Step 4 - send customer confirmation email
    _send_confirmation(order, pricing, eta)

    print(f"[{order_id}] Order fulfilled successfully")
    return {"order_id": order_id, "status": "COMPLETED"}


def _commit_inventory(items: list, order_id: str):
    for item in items:
        name = item["name"]
        qty  = int(item["qty"])
        try:
            inventory_table.update_item(
                Key={"item_name": name},
                UpdateExpression="SET stock = stock - :qty",
                ConditionExpression="stock >= :qty",
                ExpressionAttributeValues={":qty": qty},
            )
        except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
            raise BusinessRuleError(
                f"Stock for '{name}' depleted by concurrent order. "
                f"Order {order_id} cannot be fulfilled."
            )


def _update_order(order_id: str, fields: dict):
    set_expr   = "SET " + ", ".join(f"#{k} = :{k}" for k in fields)
    attr_names = {f"#{k}": k for k in fields}
    attr_vals  = {f":{k}": v for k, v in fields.items()}
    orders_table.update_item(
        Key={"order_id": order_id},
        UpdateExpression=set_expr,
        ExpressionAttributeNames=attr_names,
        ExpressionAttributeValues=attr_vals,
    )


def _send_confirmation(order: dict, pricing: dict, eta: str):
    order_id  = order["order_id"]
    customer  = order.get("customer_name", "Customer")
    items     = order["items"]
    item_lines = "\n".join(
        f"  • {i['name']} x{i['qty']} @ ${i['price']} each" for i in items
    )

    sns.publish(
        TopicArn = SNS_TOPIC_ARN,
        Subject  = f"✅ Order Confirmed - {order_id[:8].upper()}",
        Message  = f"""Hello {customer},

Your order has been confirmed and is being prepared for shipment!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ORDER SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Order ID:           {order_id}
Status:             CONFIRMED ✅

Items Ordered:
{item_lines}

Subtotal:           ${pricing['subtotal']}
Discount Applied:   -${pricing['discount_applied']}
Shipping:           ${pricing['shipping_cost']}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL:              ${pricing['final_total']}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Estimated Delivery: {eta} ({pricing['delivery_days']} business days)

Thank you for your order!
Order Pipeline Store
""",
    )


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class BusinessRuleError(Exception):
    pass
