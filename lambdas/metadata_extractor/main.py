import json
import boto3
import logging
import io
import uuid
from pypdf import PdfReader

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

def handler(event, context):
    logger.info(f"Event received: {json.dumps(event)}")

    bucket = event["bucket"]
    key = event["key"]

    logger.info(f"Extracting metadata: s3://{bucket}/{key}")

    # Descargar el PDF a memoria
    response = s3.get_object(Bucket=bucket, Key=key)
    pdf_bytes = response["Body"].read()

    # Leer el PDF
    reader = PdfReader(io.BytesIO(pdf_bytes))

    # Extraer metadata del PDF
    meta = reader.metadata or {}
    num_pages = len(reader.pages)

    title = meta.get("/Title", "") or key.split("/")[-1].replace(".pdf", "")
    author = meta.get("/Author", "Unknown")

    # Generar book_id único
    book_id = str(uuid.uuid4())

    # Extraer texto de la primera página para detectar idioma básico
    first_page_text = ""
    if num_pages > 0:
        first_page_text = reader.pages[0].extract_text() or ""

    logger.info(f"Extracted: title={title}, pages={num_pages}, author={author}")

    return {
        "bucket": bucket,
        "key": key,
        "book_id": book_id,
        "title": title,
        "author": author,
        "num_pages": num_pages,
        "file_size": event["file_size"],
        "status": "metadata_extracted"
    }
