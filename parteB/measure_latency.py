import boto3
import json
from decimal import Decimal

session = boto3.Session(profile_name="personal", region_name="us-east-1")
table = session.resource("dynamodb").Table("finsir-events")

items = []
response = table.scan(
    FilterExpression="begins_with(event_id, :prefix)",
    ExpressionAttributeValues={":prefix": "evt-"},
    ProjectionExpression="event_id, latency_ms, stored_at",
)

items.extend(response.get("Items", []))

while "LastEvaluatedKey" in response:
    response = table.scan(
        FilterExpression="begins_with(event_id, :prefix)",
        ExpressionAttributeValues={":prefix": "evt-"},
        ProjectionExpression="event_id, latency_ms, stored_at",
        ExclusiveStartKey=response["LastEvaluatedKey"],
    )
    items.extend(response.get("Items", []))

# Conserva solo los eventos de la ejecución que estás midiendo.
items = [
    item
    for item in items
    if item["event_id"].startswith("evt-") and item.get("latency_ms") is not None
]

latencies = [float(item["latency_ms"]) for item in items]

if latencies:
    print(f"Eventos con latencia: {len(latencies)}")
    print(f"Latencia promedio: {sum(latencies) / len(latencies):.2f} ms")
    print(f"Latencia máxima: {max(latencies):.2f} ms")
else:
    print("No se encontraron eventos con latency_ms.")


from datetime import datetime, timezone

for item in items[:10]:
    print(
        item["event_id"],
        "latency_ms =",
        item.get("latency_ms"),
        "stored_at =",
        item.get("stored_at"),
    )

latencies = [
    float(item["latency_ms"]) for item in items if item.get("latency_ms") is not None
]

if latencies:
    negatives = [x for x in latencies if x < 0]
    positives = [x for x in latencies if x >= 0]

    print(f"Total: {len(latencies)}")
    print(f"Negativas: {len(negatives)}")
    print(f"No negativas: {len(positives)}")
    print(f"Mínima: {min(latencies):.2f} ms")
    print(f"Promedio: {sum(latencies) / len(latencies):.2f} ms")
    print(f"Máxima: {max(latencies):.2f} ms")


