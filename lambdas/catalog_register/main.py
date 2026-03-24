import json
import boto3
import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
BOOKS_TABLE = os.environ["BOOKS_TABLE"]
BOOKS_BUCKET = os.environ["BOOKS_BUCKET"]

def handler(event, context):
    logger.info(f"Event received: {json.dumps(event)}")

    table = dynamodb.Table(BOOKS_TABLE)

    book_id = event["book_id"]
    key = event["key"]

    # Extraer género del prefijo del key si existe
    # Ejemplo: books/historia/iliada.pdf → historia
    parts = key.split("/")
    genre = parts[1] if len(parts) > 2 else "general"

    item = {
        "book_id": book_id,
        "title": event["title"],
        "author": event["author"],
        "num_pages": event["num_pages"],
        "file_size": event["file_size"],
        "genre": genre,
        "s3_key": key,
        "thumbnail_key": event["thumbnail_key"],
        "upload_date": datetime.now(timezone.utc).isoformat(),
        "status": "available"
    }

    table.put_item(Item=item)

    logger.info(f"Book registered: {book_id} - {event['title']}")

    return {
        "book_id": book_id,
        "title": event["title"],
        "status": "registered"
    }
