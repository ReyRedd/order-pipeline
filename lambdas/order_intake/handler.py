import json
import boto3
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
sqs      = boto3.client("sqs")

table     = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
queue_url = os.environ["SQS_QUEUE_URL"]


def lambda_handler(event, _context):
    try:
        body = json.loads(event.get("body") or "{}")

        required_fields = ["customer_name", "items", "total"]
        missing = [f for f in required_fields if f not in body]
        if missing:
            return _response(400, {"error": f"Missing required fields: {missing}"})

        # Convert floats → Decimal (DynamoDB rejects Python floats)
        order = json.loads(
            json.dumps({
                "order_id":      str(uuid.uuid4()),
                "customer_name": body["customer_name"],
                "items":         body["items"],
                "total":         body["total"],
                "status":        "PENDING",
                "created_at":    datetime.now(timezone.utc).isoformat(),
            }),
            parse_float=Decimal
        )

        # Step 1 — persist to DynamoDB
        table.put_item(Item=order)

        # Step 2 — publish to SQS for async processing
        # json.dumps can't handle Decimal, so we convert back to float for the message
        sqs.send_message(
            QueueUrl    = queue_url,
            MessageBody = json.dumps(order, default=str),
        )

        return _response(201, {
            "order_id": order["order_id"],
            "message":  "Order received and queued for processing",
        })

    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})
    except Exception as e:
        print(f"Unexpected error: {e}")
        return _response(500, {"error": "Internal server error"})


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
