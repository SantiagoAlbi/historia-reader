# terraform/modules/cdn/main.tf

# OAC — Origin Access Control
# Le dice a CloudFront que se identifique ante S3 con una firma
# S3 solo acepta requests que vengan de este CloudFront específico
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project_name}-oac-${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Distribución de CloudFront
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "${var.project_name}-${var.environment}"

  # Origen 1 — Frontend (S3 con el HTML/JS)
  origin {
    domain_name              = "${var.frontend_bucket_id}.s3.amazonaws.com"
    origin_id                = "frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # Origen 2 — Books (S3 con los PDFs y thumbnails)
  origin {
    domain_name              = "${var.books_bucket_id}.s3.amazonaws.com"
    origin_id                = "books"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # Comportamiento por defecto — sirve el frontend
  default_cache_behavior {
    target_origin_id       = "frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # Comportamiento para /books/* — sirve PDFs y thumbnails
  # Requiere Signed URL para acceder
  ordered_cache_behavior {
    path_pattern           = "/books/*"
    target_origin_id       = "books"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    trusted_key_groups     = [aws_cloudfront_key_group.main.id]

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Clave para firmar las URLs de los libros
resource "aws_cloudfront_public_key" "main" {
  name        = "${var.project_name}-key-${var.environment}"
  encoded_key = file("${path.module}/keys/public_key.pem")
  comment     = "Key for signing book URLs"
}

# Grupo de claves — CloudFront valida las Signed URLs contra este grupo
resource "aws_cloudfront_key_group" "main" {
  name  = "${var.project_name}-key-group-${var.environment}"
  items = [aws_cloudfront_public_key.main.id]
}

# Política de bucket — permite que CloudFront (OAC) lea de S3
resource "aws_s3_bucket_policy" "books" {
  bucket = var.books_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${var.books_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.frontend_bucket_id}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}
