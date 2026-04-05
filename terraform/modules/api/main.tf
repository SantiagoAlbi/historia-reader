# terraform/modules/api/main.tf

# Empaqueta el código Python como zip para subirlo a Lambda
data "archive_file" "backend" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/backend"
  output_path = "${path.module}/files/backend.zip"
}

# IAM Role — el "pasaporte" de la Lambda para operar en AWS
resource "aws_iam_role" "lambda_backend" {
  name = "${var.project_name}-lambda-backend-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Permisos que tiene la Lambda
resource "aws_iam_role_policy" "lambda_backend" {
  name = "${var.project_name}-lambda-backend-policy-${var.environment}"
  role = aws_iam_role.lambda_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Logs en CloudWatch
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # Leer y escribir en DynamoDB
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.books_table_arn,
          "${var.books_table_arn}/index/*",
          var.reading_progress_table_arn
        ]
      },
      # Generar Signed URLs — necesita leer del bucket
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.books_bucket_id}/*"
      },
      # Leer la clave privada de Secrets Manager para firmar URLs
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.cloudfront_private_key.arn
      }
    ]
  })
}

# Guarda la clave privada en Secrets Manager
# La Lambda la lee en runtime para firmar las Signed URLs
resource "aws_secretsmanager_secret" "cloudfront_private_key" {
  name = "${var.project_name}-cf-private-key-${var.environment}"
  recovery_window_in_days = 0
}

# Lambda function
resource "aws_lambda_function" "backend" {
  function_name    = "${var.project_name}-backend-${var.environment}"
  role             = aws_iam_role.lambda_backend.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256

 environment {
  variables = {
    BOOKS_TABLE             = var.books_table_name
    READING_PROGRESS_TABLE  = var.reading_progress_table_name
    BOOKS_BUCKET            = var.books_bucket_id
    CLOUDFRONT_DOMAIN       = var.cloudfront_domain
    CLOUDFRONT_KEY_PAIR_ID  = var.cloudfront_key_pair_id
    PRIVATE_KEY_SECRET_NAME = aws_secretsmanager_secret.cloudfront_private_key.name
    ENVIRONMENT             = var.environment
  }
}
    
  }

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

# Autorizador — valida el JWT token de Cognito en cada request
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

jwt_configuration {
  audience = [var.user_pool_client_id]
  issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.user_pool_id}"
}
}

# Stage — el environment del API (dev, prod)
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true
}

# Integración — conecta API Gateway con Lambda
resource "aws_apigatewayv2_integration" "backend" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
}

# Rutas de la API
resource "aws_apigatewayv2_route" "get_books" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /books"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_book" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /books/{book_id}"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_signed_url" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /books/{book_id}/url"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "update_progress" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "PUT /books/{book_id}/progress"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Permiso para que API Gateway invoque la Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Carpeta para el zip de Lambda
resource "null_resource" "lambda_files_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/files"
  }
}
