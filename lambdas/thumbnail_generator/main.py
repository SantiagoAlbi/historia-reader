import json
import boto3
import logging
import io
import os
import subprocess
import tempfile

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
BOOKS_BUCKET = os.environ["BOOKS_BUCKET"]

def handler(event, context):
    logger.info(f"Event received: {json.dumps(event)}")

    bucket = event["bucket"]
    key = event["key"]
    book_id = event["book_id"]

    logger.info(f"Generating thumbnail for: {key}")

    # Descargar PDF
    response = s3.get_object(Bucket=bucket, Key=key)
    pdf_bytes = response["Body"].read()

    thumbnail_key = f"thumbnails/{book_id}.jpg"

    try:
        # Usar ghostscript para renderizar la primera página
        with tempfile.TemporaryDirectory() as tmpdir:
            pdf_path = f"{tmpdir}/input.pdf"
            img_path = f"{tmpdir}/thumbnail.jpg"

            with open(pdf_path, "wb") as f:
                f.write(pdf_bytes)

            subprocess.run([
                "gs",
                "-dNOPAUSE", "-dBATCH", "-dSAFER",
                "-sDEVICE=jpeg",
                "-dFirstPage=1", "-dLastPage=1",
                "-r72",
                f"-sOutputFile={img_path}",
                pdf_path
            ], check=True, capture_output=True)

            with open(img_path, "rb") as f:
                thumbnail_bytes = f.read()

        s3.put_object(
            Bucket=BOOKS_BUCKET,
            Key=thumbnail_key,
            Body=thumbnail_bytes,
            ContentType="image/jpeg"
        )
        logger.info(f"Thumbnail saved: {thumbnail_key}")

    except Exception as e:
        logger.warning(f"Thumbnail generation failed, using placeholder: {str(e)}")
        thumbnail_key = "thumbnails/default.jpg"

    return {
        **event,
        "thumbnail_key": thumbnail_key,
        "status": "thumbnail_generated"
    }
