"""
orchestrator - SQS consumer that starts a Step Functions execution per order
============================================================================
Replaces the old order_processor Lambda.
Each SQS message triggers one Step Functions Express execution.
Step Functions handles all the business logic steps.
"""

import json
import boto3
import os

sfn = boto3.client("stepfunctions")

STATE_MACHINE_ARN = os.environ["STATE_MACHINE_ARN"]


def lambda_handler(event, _context):
    started   = []
    failed    = []

    for record in event["Records"]:
        order    = json.loads(record["body"])
        order_id = order.get("order_id", "unknown")

        try:
            # Start one Express execution per order
            # Execution name must be unique - order_id is a UUID so it qualifies
            response = sfn.start_execution(
                stateMachineArn = STATE_MACHINE_ARN,
                name            = order_id,
                input           = record["body"],
            )
            print(f"[{order_id}] Started execution: {response['executionArn']}")
            started.append(order_id)

        except sfn.exceptions.ExecutionAlreadyExists:
            # Idempotency guard - SQS at-least-once delivery may redeliver
            print(f"[{order_id}] Execution already exists - skipping duplicate")
            started.append(order_id)

        except Exception as e:
            print(f"[{order_id}] Failed to start execution: {e}")
            failed.append(order_id)
            raise   # let SQS retry

    return {"started": started, "failed": failed}
