"""
order_processor - Real e-commerce business logic + SNS notifications
=====================================================================
Flow for each order:
  PENDING → PROCESSING → COMPLETED  → SNS: "Order confirmed" email
                       ↘ FAILED     → SNS: "Order failed" email
"""

import json
import os
import boto3
from datetime import datetime, timezone, timedelta
from decimal import Decimal, ROUND_HALF_UP

dynamodb = boto3.resource("dynamodb")
sns      = boto3.client("sns")

orders_table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
inventory_table = dynamodb.Table(os.environ["INVENTORY_TABLE"])
sns_topic_arn   = os.environ["SNS_TOPIC_ARN"]


# ── Entry point ───────────────────────────────────────────────────────────────

def lambda_handler(event, _context):
    results = {"processed": [], "failed": []}

    for record in event["Records"]:
        order    = json.loads(record["body"])
        order_id = order.get("order_id", "unknown")

        try:
            print(f"[{order_id}] Starting processing")
            result = _process_order(order)
            _notify_customer(order, result, status="COMPLETED")
            results["processed"].append(order_id)
            print(f"[{order_id}] Completed successfully")

        except BusinessRuleError as e:
            print(f"[{order_id}] Business rule violation: {e}")
            _update_order(order_id, {
                "status":         "FAILED",
                "failure_reason": str(e),
                "failed_at":      _now(),
            })
            _notify_customer(order, {}, status="FAILED", reason=str(e))
            results["failed"].append(order_id)

        except Exception as e:
            print(f"[{order_id}] Unexpected error (will retry): {e}")
            raise

    return results


# ── Main pipeline ─────────────────────────────────────────────────────────────

def _process_order(order: dict) -> dict:
    order_id = order["order_id"]
    items    = order["items"]

    _update_order(order_id, {"status": "PROCESSING", "processing_started_at": _now()})

    fraud_result = _check_fraud(order)
    if fraud_result["flagged"]:
        raise BusinessRuleError(f"Fraud check failed: {fraud_result['reason']}")

    inventory = _check_inventory(items)

    calculated_total = _calculate_subtotal(items)
    submitted_total  = Decimal(str(order["total"]))
    _verify_total(submitted_total, calculated_total, order_id)

    discount         = _calculate_discount(calculated_total, items)
    discounted_total = calculated_total - discount
    shipping_cost    = _calculate_shipping(discounted_total)
    final_total      = discounted_total + shipping_cost

    _commit_inventory(items, order_id)

    delivery_days = _estimate_delivery_days(shipping_cost)
    eta = datetime.now(timezone.utc) + timedelta(days=delivery_days)

    result = {
        "subtotal":           str(calculated_total),
        "discount_applied":   str(discount),
        "shipping_cost":      str(shipping_cost),
        "final_total":        str(final_total),
        "estimated_delivery": eta.strftime("%Y-%m-%d"),
        "delivery_days":      delivery_days,
        "inventory_snapshot": inventory,
    }

    _update_order(order_id, {
        "status":            "COMPLETED",
        "completed_at":      _now(),
        **{k: v for k, v in result.items() if k != "inventory_snapshot"},
        "inventory_snapshot": inventory,
    })

    return result


# ── SNS Notifications ─────────────────────────────────────────────────────────

def _notify_customer(order: dict, result: dict, status: str, reason: str = ""):
    customer = order.get("customer_name", "Customer")
    order_id = order["order_id"]

    if status == "COMPLETED":
        subject = f"✅ Order Confirmed - {order_id[:8].upper()}"
        message = f"""Hello {customer},

Your order has been confirmed and is being prepared for shipment!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ORDER SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Order ID:           {order_id}
Status:             CONFIRMED ✅

Items Ordered:
{_format_items(order.get('items', []))}

Subtotal:           ${result.get('subtotal', '0.00')}
Discount Applied:   -${result.get('discount_applied', '0.00')}
Shipping:           ${result.get('shipping_cost', '0.00')}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL:              ${result.get('final_total', '0.00')}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Estimated Delivery: {result.get('estimated_delivery', 'TBD')} ({result.get('delivery_days', '?')} business days)

Thank you for your order!
Order Pipeline Store
"""

    else:
        subject = f"❌ Order Could Not Be Processed - {order_id[:8].upper()}"
        message = f"""Hello {customer},

Unfortunately we were unable to process your order.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ORDER DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Order ID:   {order_id}
Status:     FAILED ❌
Reason:     {reason}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

No charges have been made. Please review your order and try again.

Order Pipeline Store
"""

    sns.publish(
        TopicArn = sns_topic_arn,
        Subject  = subject,
        Message  = message,
    )
    print(f"[{order_id}] SNS notification sent - {status}")


def _format_items(items: list) -> str:
    lines = []
    for item in items:
        name  = item.get("name", "Unknown")
        qty   = item.get("qty", 1)
        price = item.get("price", 0)
        lines.append(f"  • {name} x{qty} @ ${price} each")
    return "\n".join(lines)


# ── Business logic (unchanged from Phase 2) ───────────────────────────────────

def _check_fraud(order: dict) -> dict:
    items = order["items"]
    total = Decimal(str(order["total"]))
    for item in items:
        if int(item["qty"]) > 50:
            return {"flagged": True, "reason": f"Unusually high quantity ({item['qty']}) for item '{item['name']}'"}
    if total > Decimal("10000"):
        return {"flagged": True, "reason": f"Order total ${total} exceeds single-order limit of $10,000"}
    for item in items:
        if Decimal(str(item["price"])) <= 0:
            return {"flagged": True, "reason": f"Invalid price ({item['price']}) for item '{item['name']}'"}
    return {"flagged": False, "reason": None}


def _check_inventory(items: list) -> dict:
    snapshot = {}
    for item in items:
        name       = item["name"]
        qty_needed = int(item["qty"])
        response   = inventory_table.get_item(Key={"item_name": name})
        record     = response.get("Item")
        if not record:
            raise BusinessRuleError(f"Item '{name}' not found in inventory catalogue")
        stock = int(record["stock"])
        snapshot[name] = {"available": stock, "requested": qty_needed}
        if stock < qty_needed:
            raise BusinessRuleError(f"Insufficient stock for '{name}': requested {qty_needed}, available {stock}")
    return snapshot


def _calculate_subtotal(items: list) -> Decimal:
    total = Decimal("0")
    for item in items:
        total += Decimal(str(item["price"])) * Decimal(str(item["qty"]))
    return total.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _verify_total(submitted: Decimal, calculated: Decimal, order_id: str):
    tolerance = Decimal("0.02")
    diff = abs(submitted - calculated)
    if diff > tolerance:
        raise BusinessRuleError(
            f"Total mismatch for order {order_id}: "
            f"client submitted ${submitted}, server calculated ${calculated} (diff ${diff})"
        )


def _calculate_discount(subtotal: Decimal, items: list) -> Decimal:
    discount = Decimal("0")
    if subtotal >= Decimal("500"):
        discount = subtotal * Decimal("0.15")
    elif subtotal >= Decimal("250"):
        discount = subtotal * Decimal("0.10")
    elif subtotal >= Decimal("100"):
        discount = subtotal * Decimal("0.05")
    if len(items) >= 3:
        discount += Decimal("5.00")
    return discount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _calculate_shipping(discounted_total: Decimal) -> Decimal:
    if discounted_total >= Decimal("100"):
        return Decimal("0.00")
    elif discounted_total >= Decimal("50"):
        return Decimal("4.99")
    else:
        return Decimal("8.99")


def _estimate_delivery_days(shipping_cost: Decimal) -> int:
    if shipping_cost == Decimal("0.00"):
        return 3
    elif shipping_cost == Decimal("4.99"):
        return 5
    else:
        return 7


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
                f"Stock for '{name}' was depleted by a concurrent order. "
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


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class BusinessRuleError(Exception):
    pass
