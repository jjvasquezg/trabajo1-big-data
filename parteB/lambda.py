import json
import os
import logging
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ.get("TABLE_NAME", "finsir-events")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

REQUIRED_FIELDS = {
    "event_id",
    "customer_id",
    "event_type",
    "product_id",
    "event_timestamp",
}


def log_event(status, message_id, **details):
    """Write structured JSON logs to CloudWatch."""
    logger.info(
        json.dumps(
            {
                "status": status,
                "sqs_message_id": message_id,
                **details,
            },
            default=str,
        )
    )


def reject_message(message_id, reason, event_id=None):
    """Record an invalid event without retrying it."""
    log_event(
        "REJECTED",
        message_id,
        event_id=event_id,
        reason=reason,
    )


def lambda_handler(event, context):
    batch_item_failures = []

    records = event.get("Records", [])

    logger.info(
        json.dumps(
            {
                "status": "BATCH_STARTED",
                "record_count": len(records),
                "aws_request_id": context.aws_request_id,
            }
        )
    )

    for record in records:
        message_id = record.get("messageId", "unknown")

        try:
            # 1. Parse the SQS message body.
            body = record.get("body", "")
            payload = json.loads(body)

            if not isinstance(payload, dict):
                reject_message(
                    message_id,
                    "JSON payload must be an object",
                )
                continue

            event_id = payload.get("event_id")

            # 2. Validate the required fields.
            missing_fields = REQUIRED_FIELDS - payload.keys()

            if missing_fields:
                reject_message(
                    message_id,
                    "Missing required fields: " + ", ".join(sorted(missing_fields)),
                    event_id=event_id,
                )
                continue

            # 3. Validate basic field values.
            invalid_fields = []

            for field in REQUIRED_FIELDS:
                value = payload.get(field)

                if not isinstance(value, str) or not value.strip():
                    invalid_fields.append(field)

            if invalid_fields:
                reject_message(
                    message_id,
                    "Fields must be non-empty strings: "
                    + ", ".join(sorted(invalid_fields)),
                    event_id=event_id,
                )
                continue

            # 4. Parse the event timestamp.
            timestamp_text = payload["event_timestamp"]

            try:
                normalized_timestamp = timestamp_text.replace("Z", "+00:00")
                event_time = datetime.fromisoformat(normalized_timestamp)

                if event_time.tzinfo is None:
                    raise ValueError("Timestamp must include a timezone")

                event_time = event_time.astimezone(timezone.utc)

            except ValueError:
                reject_message(
                    message_id,
                    "event_timestamp must be valid ISO 8601 with a timezone",
                    event_id=event_id,
                )
                continue

            # 5. Calculate latency using the AWS IoT Rules timestamp.
            try:
                iot_received_ms = int(payload["iot_received_ms"])

                iot_received_time = datetime.fromtimestamp(
                    iot_received_ms / 1000,
                    tz=timezone.utc,
                )
            except (KeyError, TypeError, ValueError, OverflowError):
                reject_message(
                    message_id,
                    "Missing or invalid iot_received_ms",
                    event_id=event_id,
                )
                continue

            processing_time = datetime.now(timezone.utc)

            latency_ms = Decimal(
                str(
                    round(
                        (processing_time - iot_received_time).total_seconds() * 1000,
                        2,
                    )
                )
            )

            logger.info(
                json.dumps(
                    {
                        "status": "DIAGNOSTIC",
                        "event_id": event_id,
                        "event_timestamp": event_time.isoformat(),
                        "iot_received_at": iot_received_time.isoformat(),
                        "lambda_time": processing_time.isoformat(),
                        "latency_ms": latency_ms,
                    },
                    default=str,
                )
            )

            # 6. Prepare the DynamoDB item.
            item = {
                "event_id": payload["event_id"],
                "customer_id": payload["customer_id"],
                "event_type": payload["event_type"],
                "product_id": payload["product_id"],
                "event_timestamp": event_time.isoformat(),
                "iot_received_at": iot_received_time.isoformat(),
                "stored_at": processing_time.isoformat(),
                "latency_ms": latency_ms,
                "status": "ACCEPTED",
            }

            # 7. Persist the event, avoiding overwrites of an
            # existing event with the same event_id.
            table.put_item(
                Item=item,
                ConditionExpression="attribute_not_exists(event_id)",
            )

            log_event(
                "ACCEPTED",
                message_id,
                event_id=event_id,
                latency_ms=latency_ms,
            )

        except json.JSONDecodeError:
            # Invalid JSON is a permanent data error.
            reject_message(
                message_id,
                "Message body is not valid JSON",
            )

        except ClientError as exc:
            error_code = exc.response.get("Error", {}).get("Code", "Unknown")

            if error_code == "ConditionalCheckFailedException":
                # The event_id already exists. Treat the message
                # as a duplicate, not as a technical failure.
                log_event(
                    "DUPLICATE",
                    message_id,
                    reason="event_id already exists",
                )
            else:
                # Infrastructure or service error: retry this item.
                logger.exception(
                    "Technical error processing message %s",
                    message_id,
                )
                batch_item_failures.append({"itemIdentifier": message_id})

        except Exception:
            # Unexpected technical error: request a retry.
            logger.exception(
                "Unexpected error processing message %s",
                message_id,
            )
            batch_item_failures.append({"itemIdentifier": message_id})

    logger.info(
        json.dumps(
            {
                "status": "BATCH_FINISHED",
                "processed_records": len(records),
                "failed_records": len(batch_item_failures),
            }
        )
    )

    return {"batchItemFailures": batch_item_failures}
