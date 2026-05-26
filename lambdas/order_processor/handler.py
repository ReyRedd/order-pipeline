"""
order_processor — Real e-commerce business logic
=================================================
Flow for each order:
  PENDING → PROCESSING → VALIDATED → COMPLETED
                       ↘ FAILED (on business rule violation)

Business rules applied:
  1. Fraud detection     — flag suspicious orders before touching inventory
  2. Inventory check     — ensure stock exists (per-item in DynamoDB)
  3. Total verification  — recalculate total server-side (never trust the client)
  4. Discount engine     — apply threshold / bulk discounts
  5. Shipping calculator — tiered rates based on verified total
  6. Inventory commit    — atomically decrement stock
  7. Order enrichment    — write final totals, shipping, ETA back to DynamoDB
"""

import json
import os
import boto3
from datetime import datetime, timezone, timedelta
from decimal import Decimal, ROUND_HALF_UP

dynamodb = boto3.resource("dynamodb")
orders_table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
inventory_table = dynamodb.Table(os.environ["INVENTORY_TABLE"])


# ── Entry point ───────────────────────────────────────────────────────────────

def lambda_handler(event, _context):
    results = {"processed": [], "failed": []}

    for record in event["Records"]:
        order = json.loads(record["body"])
        order_id = order.get("order_id", "unknown")

        try:
            print(f"[{order_id}] Starting processing")
            _process_order(order)
            results["processed"].append(order_id)
            print(f"[{order_id}] Completed successfully")

        except BusinessRuleError as e:
            # Known violation — mark order FAILED, don't retry
            print(f"[{order_id}] Business rule violation: {e}")
            _update_order(order_id, {
                "status":       "FAILED",
                "failure_reason": str(e),
                "failed_at":    _now(),
            })
            results["failed"].append(order_id)

        except Exception as e:
            # Unexpected error - let SQS retry (up to maxReceiveCount, then DLQ)
            print(f"[{order_id}] Unexpected error (will retry): {e}")
            raise

    return results


# ── Main pipeline ─────────────────────────────────────────────────────────────

def _process_order(order: dict):
    order_id = order["order_id"]
    items    = order["items"]          # [{"name": "Widget", "qty": 2, "price": 9.99}]

    # Step 1 - mark as in-progress immediately
    _update_order(order_id, {"status": "PROCESSING", "processing_started_at": _now()})

    # Step 2 - fraud detection (fast, before any DB writes)
    fraud_result = _check_fraud(order)
    if fraud_result["flagged"]:
        raise BusinessRuleError(f"Fraud check failed: {fraud_result['reason']}")

    # Step 3 - verify inventory availability (read-only, no commit yet)
    inventory = _check_inventory(items)

    # Step 4 - recalculate total server-side (never trust client-submitted totals)
    calculated_total = _calculate_subtotal(items)
    submitted_total  = Decimal(str(order["total"]))
    _verify_total(submitted_total, calculated_total, order_id)

    # Step 5 - apply discounts
    discount        = _calculate_discount(calculated_total, items)
    discounted_total = calculated_total - discount

    # Step 6 - calculate shipping
    shipping_cost = _calculate_shipping(discounted_total)
    final_total   = discounted_total + shipping_cost

    # Step 7 - commit inventory (atomic decrement per item)
    _commit_inventory(items, order_id)

    # Step 8 - enrich order record with final computed values
    eta = datetime.now(timezone.utc) + timedelta(days=_estimate_delivery_days(shipping_cost))
    _update_order(order_id, {
        "status":            "COMPLETED",
        "subtotal":          str(calculated_total),
        "discount_applied":  str(discount),
        "shipping_cost":     str(shipping_cost),
        "final_total":       str(final_total),
        "estimated_delivery": eta.strftime("%Y-%m-%d"),
        "completed_at":      _now(),
        "inventory_snapshot": inventory,
    })


# ── Step 2: Fraud detection ───────────────────────────────────────────────────

def _check_fraud(order: dict) -> dict:
    """
    Simple rule-based fraud detection.
    In production you'd call a dedicated fraud service (e.g. AWS Fraud Detector).
    """
    items = order["items"]
    total = Decimal(str(order["total"]))

    # Rule 1 - single item quantity over threshold
    for item in items:
        if int(item["qty"]) > 50:
            return {"flagged": True, "reason": f"Unusually high quantity ({item['qty']}) for item '{item['name']}'"}

    # Rule 2 - order total suspiciously high for a single order
    if total > Decimal("10000"):
        return {"flagged": True, "reason": f"Order total ${total} exceeds single-order limit of $10,000"}

    # Rule 3 - negative or zero price submitted
    for item in items:
        if Decimal(str(item["price"])) <= 0:
            return {"flagged": True, "reason": f"Invalid price ({item['price']}) for item '{item['name']}'"}

    return {"flagged": False, "reason": None}


# ── Step 3: Inventory check ───────────────────────────────────────────────────

def _check_inventory(items: list) -> dict:
    """
    Checks stock levels for each item.
    Returns a snapshot of current stock for auditing.
    If any item is out of stock, raises BusinessRuleError.
    """
    snapshot = {}

    for item in items:
        name     = item["name"]
        qty_needed = int(item["qty"])

        response = inventory_table.get_item(Key={"item_name": name})
        record   = response.get("Item")

        if not record:
            raise BusinessRuleError(f"Item '{name}' not found in inventory catalogue")

        stock = int(record["stock"])
        snapshot[name] = {"available": stock, "requested": qty_needed}

        if stock < qty_needed:
            raise BusinessRuleError(
                f"Insufficient stock for '{name}': requested {qty_needed}, available {stock}"
            )

    return snapshot


# ── Step 4: Total verification ────────────────────────────────────────────────

def _calculate_subtotal(items: list) -> Decimal:
    total = Decimal("0")
    for item in items:
        total += Decimal(str(item["price"])) * Decimal(str(item["qty"]))
    return total.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _verify_total(submitted: Decimal, calculated: Decimal, order_id: str):
    """
    Allows ±$0.02 tolerance for floating-point rounding from the client.
    Rejects anything beyond that — prevents price tampering.
    """
    tolerance = Decimal("0.02")
    diff = abs(submitted - calculated)
    if diff > tolerance:
        raise BusinessRuleError(
            f"Total mismatch for order {order_id}: "
            f"client submitted ${submitted}, server calculated ${calculated} "
            f"(diff ${diff} exceeds tolerance ${tolerance})"
        )


# ── Step 5: Discount engine ───────────────────────────────────────────────────

def _calculate_discount(subtotal: Decimal, items: list) -> Decimal:
    """
    Tiered discount rules (stackable):
      - Order total ≥ $100  → 5% off
      - Order total ≥ $250  → 10% off
      - Order total ≥ $500  → 15% off
      - 3+ distinct items   → extra $5 off (bundle discount)
    Highest tier wins; bundle discount stacks on top.
    """
    discount = Decimal("0")

    # Tier discount
    if subtotal >= Decimal("500"):
        discount = subtotal * Decimal("0.15")
    elif subtotal >= Decimal("250"):
        discount = subtotal * Decimal("0.10")
    elif subtotal >= Decimal("100"):
        discount = subtotal * Decimal("0.05")

    # Bundle discount
    if len(items) >= 3:
        discount += Decimal("5.00")

    return discount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


# ── Step 6: Shipping calculator ───────────────────────────────────────────────

def _calculate_shipping(discounted_total: Decimal) -> Decimal:
    """
    Shipping tiers (after discounts):
      - Under $50  → $8.99 standard
      - $50–$99    → $4.99 economy
      - $100+      → FREE
    """
    if discounted_total >= Decimal("100"):
        return Decimal("0.00")
    elif discounted_total >= Decimal("50"):
        return Decimal("4.99")
    else:
        return Decimal("8.99")


def _estimate_delivery_days(shipping_cost: Decimal) -> int:
    """Maps shipping cost to estimated delivery window."""
    if shipping_cost == Decimal("0.00"):
        return 3   # free shipping - 3 business days
    elif shipping_cost == Decimal("4.99"):
        return 5   # economy - 5 business days
    else:
        return 7   # standard - up to 7 business days


# ── Step 7: Inventory commit ──────────────────────────────────────────────────

def _commit_inventory(items: list, order_id: str):
    """
    Atomically decrements stock for each item.
    Uses a condition expression to prevent going below zero
    (guards against race conditions from concurrent orders).
    """
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
            # Stock dropped between check and commit (race condition)
            raise BusinessRuleError(
                f"Stock for '{name}' was depleted by a concurrent order. "
                f"Order {order_id} cannot be fulfilled."
            )


# ── Step 8: Order enrichment helper ──────────────────────────────────────────

def _update_order(order_id: str, fields: dict):
    """Writes arbitrary fields back to the orders table."""
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


# ── Custom exception ──────────────────────────────────────────────────────────

class BusinessRuleError(Exception):
    """Raised for known violations — order is marked FAILED, not retried."""
    pass
