import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import boto3

BUCKET = os.environ["BUCKET_NAME"]
API_URL = "https://api.fda.gov/drug/event.json"
LIMIT = int(os.environ.get("LIMIT", "100"))

s3 = boto3.client("s3")


def fetch_events():
    params = urllib.parse.urlencode({"sort": "receivedate:desc", "limit": LIMIT})
    with urllib.request.urlopen(f"{API_URL}?{params}", timeout=30) as resp:
        return json.loads(resp.read())


def lambda_handler(event, context):
    now = datetime.now(timezone.utc)
    results = fetch_events().get("results", [])

    key = f"openfda/drug_event/ingest_date={now:%Y-%m-%d}/events_{now:%H%M%S}.json"
    body = "\n".join(json.dumps(r) for r in results)

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=body.encode("utf-8"),
        ContentType="application/x-ndjson",
    )
    return {"records": len(results), "s3_key": key}