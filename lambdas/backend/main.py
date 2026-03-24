import json
import boto3
import logging
import os
from datetime import datetime, timezone, timedelta
from botocore.signers import CloudFrontSigner
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
secretsmanager = boto3.client("secretsmanager")

BOOKS_TABLE = os.environ["BOOKS_TABLE"]
READING_PROGRESS_TABLE = os.environ["READING_PROGRESS_TABLE"]
BOOKS_BUCKET = os.environ["BOOKS_BUCKET"]
CLOUDFRONT_DOMAIN = os.environ["CLOUDFRONT_DOMAIN"]
PRIVATE_KEY_SECRET_NAME = os.environ["PRIVATE_KEY_SECRET_NAME"]

def get_private_key():
    response = secretsmanager.get_secret_value(SecretId=PRIVATE_KEY_SECRET_NAME)
    return response["SecretString"]

def rsa_signer(message):
    private_key_pem = get_private_key()
    private_key = serialization.load_pem_private_key(
        private_key_pem.encode(), password=None
    )
    return private_key.sign(message, padding.PKCS1v15(), hashes.SHA1())

def generate_signed_url(key, key_pair_id, expiry_hours=1):
    expire_date = datetime.now(timezone.utc) + timedelta(hours=expiry_hours)
    cloudfront_signer = CloudFrontSigner(key_pair_id, rsa_signer)
    url = f"https://{CLOUDFRONT_DOMAIN}/{key}"
    return cloudfront_signer.generate_presigned_url(url, date_less_than=expire_date)

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }

def get_user_id(event):
    claims = event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})
    return claims.get("sub", "unknown")

def list_books(event):
    table = dynamodb.Table(BOOKS_TABLE)
    genre = event.get("queryStringParameters", {}) or {}
    genre = genre.get("genre")

    if genre:
        result = table.query(
            IndexName="genre-upload-index",
            KeyConditionExpression="genre = :g",
            ExpressionAttributeValues={":g": genre}
        )
    else:
        result = table.scan()

    return response(200, {"books": result["Items"]})

def get_book(book_id):
    table = dynamodb.Table(BOOKS_TABLE)
    result = table.get_item(Key={"book_id": book_id})
    book = result.get("Item")

    if not book:
        return response(404, {"error": "Book not found"})

    return response(200, {"book": book})

def get_signed_url(event, book_id):
    table = dynamodb.Table(BOOKS_TABLE)
    result = table.get_item(Key={"book_id": book_id})
    book = result.get("Item")

    if not book:
        return response(404, {"error": "Book not found"})

    key_pair_id = os.environ.get("CLOUDFRONT_KEY_PAIR_ID", "")
    signed_url = generate_signed_url(book["s3_key"], key_pair_id)

    return response(200, {"url": signed_url, "expires_in": "1 hour"})

def update_progress(event, book_id):
    user_id = get_user_id(event)
    body = json.loads(event.get("body") or "{}")
    current_page = body.get("current_page", 1)

    table = dynamodb.Table(READING_PROGRESS_TABLE)
    table.put_item(Item={
        "user_id": user_id,
        "book_id": book_id,
        "current_page": current_page,
        "last_read_date": datetime.now(timezone.utc).isoformat()
    })

    return response(200, {"status": "progress updated"})

def handler(event, context):
    logger.info(f"Event: {json.dumps(event)}")

    route = event.get("routeKey", "")
    path_params = event.get("pathParameters") or {}
    book_id = path_params.get("book_id")

    routes = {
        "GET /books": lambda: list_books(event),
        "GET /books/{book_id}": lambda: get_book(book_id),
        "GET /books/{book_id}/url": lambda: get_signed_url(event, book_id),
        "PUT /books/{book_id}/progress": lambda: update_progress(event, book_id),
    }

    handler_fn = routes.get(route)
    if not handler_fn:
        return response(404, {"error": f"Route not found: {route}"})

    try:
        return handler_fn()
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return response(500, {"error": "Internal server error"})
