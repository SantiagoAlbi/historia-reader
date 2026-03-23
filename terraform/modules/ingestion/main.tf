# terraform/modules/ingestion/main.tf

data "archive_file" "validation" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/validation"
  output_path = "${path.module}/files/validation.zip"
}

data "archive_file" "metadata_extractor" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/metadata_extractor"
  output_path = "${path.module}/files/metadata_extractor.zip"
}

data "archive_file" "thumbnail_generator" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/thumbnail_generator"
  output_path = "${path.module}/files/thumbnail_generator.zip"
}

data "archive_file" "catalog_register" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/catalog_register"
  output_path = "${path.module}/files/catalog_register.zip"
}

resource "aws_iam_role" "lambda_ingestion" {
  name = "${var.project_name}-lambda-ingestion-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_ingestion" {
  name = "${var.project_name}-lambda-ingestion-policy-${var.environment}"
  role = aws_iam_role.lambda_ingestion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${var.books_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = var.books_table_arn
      }
    ]
  })
}

resource "aws_lambda_function" "validation" {
  function_name    = "${var.project_name}-validation-${var.environment}"
  role             = aws_iam_role.lambda_ingestion.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.validation.output_path
  source_code_hash = data.archive_file.validation.output_base64sha256

  environment {
    variables = {
      BOOKS_BUCKET = var.books_bucket_id
    }
  }
}

resource "aws_lambda_function" "metadata_extractor" {
  function_name    = "${var.project_name}-metadata-extractor-${var.environment}"
  role             = aws_iam_role.lambda_ingestion.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.metadata_extractor.output_path
  source_code_hash = data.archive_file.metadata_extractor.output_base64sha256

  environment {
    variables = {
      BOOKS_BUCKET = var.books_bucket_id
    }
  }
}

resource "aws_lambda_function" "thumbnail_generator" {
  function_name    = "${var.project_name}-thumbnail-generator-${var.environment}"
  role             = aws_iam_role.lambda_ingestion.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.thumbnail_generator.output_path
  source_code_hash = data.archive_file.thumbnail_generator.output_base64sha256

  environment {
    variables = {
      BOOKS_BUCKET = var.books_bucket_id
    }
  }
}

resource "aws_lambda_function" "catalog_register" {
  function_name    = "${var.project_name}-catalog-register-${var.environment}"
  role             = aws_iam_role.lambda_ingestion.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.catalog_register.output_path
  source_code_hash = data.archive_file.catalog_register.output_base64sha256

  environment {
    variables = {
      BOOKS_TABLE  = var.books_table_name
      BOOKS_BUCKET = var.books_bucket_id
    }
  }
}

resource "aws_sfn_state_machine" "ingestion" {
  name     = "${var.project_name}-ingestion-${var.environment}"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "PDF ingestion pipeline"
    StartAt = "Validation"
    States = {
      Validation = {
        Type     = "Task"
        Resource = aws_lambda_function.validation.arn
        Next     = "MetadataExtraction"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "IngestionFailed"
        }]
      }
      MetadataExtraction = {
        Type     = "Task"
        Resource = aws_lambda_function.metadata_extractor.arn
        Next     = "ThumbnailGeneration"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "IngestionFailed"
        }]
      }
      ThumbnailGeneration = {
        Type     = "Task"
        Resource = aws_lambda_function.thumbnail_generator.arn
        Next     = "CatalogRegister"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "IngestionFailed"
        }]
      }
      CatalogRegister = {
        Type     = "Task"
        Resource = aws_lambda_function.catalog_register.arn
        Next     = "IngestionSucceeded"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "IngestionFailed"
        }]
      }
      IngestionSucceeded = {
        Type = "Succeed"
      }
      IngestionFailed = {
        Type  = "Fail"
        Error = "IngestionError"
        Cause = "Pipeline step failed"
      }
    }
  })
}

resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-sfn-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.project_name}-sfn-policy-${var.environment}"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["lambda:InvokeFunction"]
      Resource = [
        aws_lambda_function.validation.arn,
        aws_lambda_function.metadata_extractor.arn,
        aws_lambda_function.thumbnail_generator.arn,
        aws_lambda_function.catalog_register.arn
      ]
    }]
  })
}

resource "aws_iam_role" "eventbridge" {
  name = "${var.project_name}-eventbridge-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "${var.project_name}-eventbridge-policy-${var.environment}"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.ingestion.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "book_uploaded" {
  name = "${var.project_name}-book-uploaded-${var.environment}"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [var.books_bucket_id] }
      object = { key = [{ prefix = "books/" }] }
    }
  })
}

resource "aws_cloudwatch_event_target" "start_ingestion" {
  rule     = aws_cloudwatch_event_rule.book_uploaded.name
  arn      = aws_sfn_state_machine.ingestion.arn
  role_arn = aws_iam_role.eventbridge.arn
}

resource "aws_s3_bucket_notification" "books" {
  bucket      = var.books_bucket_id
  eventbridge = true
}

resource "aws_sns_topic" "ingestion_notifications" {
  name = "${var.project_name}-ingestion-${var.environment}"
}

resource "null_resource" "ingestion_files_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/files"
  }
}
