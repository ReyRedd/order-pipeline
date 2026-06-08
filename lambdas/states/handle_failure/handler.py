"""
State 5: HandleFailure
======================
Called by Step Functions Catch blocks when any state raises BusinessRuleError.
Updates order to FAILED in DynamoDB and sends failure email via SNS.
"""

import boto3
import os
from datetime import datetime, timezone

dynamodb     = boto3.resource("dynamodb")
sns          = boto3.client("sns")
orders_table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, _context):
    """
    Step Functions passes the Catch output as:
    {
      ...original order fields...,
      "error": {
        "Error": "BusinessRuleError",
        "Cause": "Fraud: unusually high quantity..."
      }
    }
    """
    order_id = event.get("order_id", "unknown")
    customer = event.get("customer_name", "Customer")
    error    = event.get("error", {})
    reason   = error.get("Cause", "Unknown error")

    print(f"[{order_id}] Handling failure: {reason}")

    # Update order status to FAILED
    _update_order(order_id, {
        "status":         "FAILED",
        "failure_reason": reason,
        "failed_at":      _now(),
    })

    # Send failure email to customer
    _send_failure_email(order_id, customer, reason)

    return {"order_id": order_id, "status": "FAILED", "reason": reason}


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


def _send_failure_email(order_id: str, customer: str, reason: str):
    sns.publish(
        TopicArn = SNS_TOPIC_ARN,
        Subject  = f"❌ Order Could Not Be Processed - {order_id[:8].upper()}",
        Message  = f"""Hello {customer},

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
""",
    )


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
