"""
State 1: ValidateOrder
======================
Runs fraud detection and server-side total verification.
Input:  full order object from Step Functions
Output: order object (unchanged - validation passed)
Raises: BusinessRuleError on any violation → Step Functions routes to HandleFailure
"""

import json
from decimal import Decimal


def lambda_handler(event, _context):
    order = event  # Step Functions passes the full state as input
    items = order["items"]
    total = Decimal(str(order["total"]))

    # ── Fraud detection ───────────────────────────────────────────────────────
    for item in items:
        qty   = int(item["qty"])
        price = Decimal(str(item["price"]))

        if qty > 50:
            raise BusinessRuleError(
                f"Fraud: unusually high quantity ({qty}) for '{item['name']}'"
            )
        if price <= 0:
            raise BusinessRuleError(
                f"Fraud: invalid price ({price}) for '{item['name']}'"
            )

    if total > Decimal("10000"):
        raise BusinessRuleError(
            f"Fraud: order total ${total} exceeds single-order limit of $10,000"
        )

    # ── Total verification ────────────────────────────────────────────────────
    calculated = sum(
        Decimal(str(i["price"])) * Decimal(str(i["qty"])) for i in items
    )
    diff = abs(total - calculated)
    if diff > Decimal("0.02"):
        raise BusinessRuleError(
            f"Total mismatch: client submitted ${total}, "
            f"server calculated ${calculated:.2f} (diff ${diff:.2f})"
        )

    print(f"[{order['order_id']}] Validation passed")
    return order   # pass the full order to the next state


class BusinessRuleError(Exception):
    pass
