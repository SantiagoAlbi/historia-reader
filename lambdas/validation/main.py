import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

def handler(event, context):
    logger.info(f"Event received: {json.dumps(event)}")

    bucket = event["detail"]["bucket"]["name"]
    key = event["detail"]["object"]["key"]

    logger.info(f"Validating: s3://{bucket}/{key}")

    # Verificar que el archivo existe y obtener metadata
    try:
        response = s3.head_object(Bucket=bucket, Key=key)
    except Exception as e:
        raise Exception(f"File not found: {str(e)}")

    content_type = response.get("ContentType", "")
    file_size = response.get("ContentLength", 0)

    # Validar que es un PDF
    if not key.lower().endswith(".pdf"):
        raise Exception(f"Invalid file type: {key}")

    # Validar tamaño mínimo (1KB) y máximo (100MB)
    if file_size < 1024:
        raise Exception(f"File too small: {file_size} bytes")

    if file_size > 100 * 1024 * 1024:
        raise Exception(f"File too large: {file_size} bytes")

    logger.info(f"Validation passed: {key}, size: {file_size}")

    return {
        "bucket": bucket,
        "key": key,
        "file_size": file_size,
        "status": "validated"
    }
