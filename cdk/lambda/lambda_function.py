import json
import os
import boto3
from decimal import Decimal

_table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    # Extract the Cognito user ID from the verified JWT claims.
    # API Gateway injects these after validating the token — the client cannot spoof this.
    try:
        user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except KeyError:
        return {"statusCode": 401, "body": "Missing auth claims"}

    try:
        body = json.loads(event["body"])
    except (KeyError, json.JSONDecodeError) as e:
        return {"statusCode": 400, "body": f"Bad request: {e}"}

    required = ["submission_time", "latitude", "longitude",
                "humidity_pct", "pm25", "pm10",
                "congestion", "headaches", "fatigue", "mood"]
    missing = [k for k in required if k not in body]
    if missing:
        return {"statusCode": 400, "body": f"Missing fields: {missing}"}

    _table.put_item(Item={
        "user_id":         user_id,
        "submission_time": body["submission_time"],
        "latitude":          Decimal(str(body["latitude"])),
        "longitude":         Decimal(str(body["longitude"])),
        "humidity_pct":      int(body["humidity_pct"]),
        "pm25":              Decimal(str(body["pm25"])),
        "pm10":              Decimal(str(body["pm10"])),
        "congestion":        int(body["congestion"]),
        "headaches":         int(body["headaches"]),
        "fatigue":           int(body["fatigue"]),
        "mood":              int(body["mood"]),
    })

    return {"statusCode": 200, "body": "ok"}
