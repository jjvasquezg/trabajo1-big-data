import json
import os
import time
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

import boto3
from botocore.config import Config

REGION = os.environ["AWS_REGION"]
ENDPOINT = os.environ["IOT_ENDPOINT"]
TOPIC = "finsir/events"
TOTAL = 10_000
WORKERS = 10

client = boto3.client(
    "iot-data",
    region_name=REGION,
    endpoint_url=f"https://{ENDPOINT}",
    config=Config(retries={"max_attempts": 5, "mode": "standard"}),
)


def publish_event(i):
    event = {
        "event_id": f"evt-{i:06d}",
        "customer_id": f"customer-{(i % 1000) + 1:04d}",
        "event_type": "recommendation_requested",
        "product_id": "ind_tjcr_fin_ult1",
        "event_timestamp": datetime.now(timezone.utc).isoformat(),
    }

    # Deliberately invalidate 1% of events.
    # These events are published but should be rejected by Lambda.
    if i % 100 == 0:
        del event["product_id"]

    response = client.publish(
        topic=TOPIC,
        qos=0,
        payload=json.dumps(event).encode("utf-8"),
    )

    return response["ResponseMetadata"]["HTTPStatusCode"]


def main():
    started = time.monotonic()
    succeeded = 0
    failed = 0

    with ThreadPoolExecutor(max_workers=WORKERS) as executor:
        futures = [executor.submit(publish_event, i) for i in range(1, TOTAL + 1)]

        for future in as_completed(futures):
            try:
                status = future.result()
                if status == 200:
                    succeeded += 1
                else:
                    failed += 1
            except Exception as exc:
                failed += 1
                print(f"Publication error: {exc}")

    elapsed = time.monotonic() - started

    print(f"Events attempted: {TOTAL}")
    print(f"API accepted: {succeeded}")
    print(f"Publication failures: {failed}")
    print(f"Elapsed seconds: {elapsed:.2f}")


if __name__ == "__main__":
    main()
