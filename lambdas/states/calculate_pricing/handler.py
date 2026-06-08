"""
State 3: CalculatePricing
=========================
Applies discount rules and calculates shipping.
Input:  order object (with inventory_snapshot from State 2)
Output: order object enriched with pricing fields
"""

from decimal import Decimal, ROUND_HALF_UP


def lambda_handler(event, _context):
    order = event
    items = order["items"]

    subtotal = _calculate_subtotal(items)
    discount = _calculate_discount(subtotal, items)
    discounted_total = subtotal - discount
    shipping_cost    = _calculate_shipping(discounted_total)
    final_total      = discounted_total + shipping_cost
    delivery_days    = _estimate_delivery_days(shipping_cost)

    pricing = {
        "subtotal":           str(subtotal),
        "discount_applied":   str(discount),
        "shipping_cost":      str(shipping_cost),
        "final_total":        str(final_total),
        "delivery_days":      delivery_days,
    }

    print(f"[{order['order_id']}] Pricing calculated: {pricing}")
    return {**order, "pricing": pricing}


def _calculate_subtotal(items: list) -> Decimal:
    total = Decimal("0")
    for item in items:
        total += Decimal(str(item["price"])) * Decimal(str(item["qty"]))
    return total.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _calculate_discount(subtotal: Decimal, items: list) -> Decimal:
    """
    Tier discounts (highest applies):
      ≥ $500 → 15%  |  ≥ $250 → 10%  |  ≥ $100 → 5%
    Bundle: 3+ distinct items → extra $5
    """
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
    """
    ≥ $100 → FREE  |  ≥ $50 → $4.99  |  < $50 → $8.99
    """
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
