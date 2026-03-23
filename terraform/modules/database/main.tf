# Tabla de catálogo de libros
resource "aws_dynamodb_table" "books" {
  name         = "${var.project_name}-books-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "book_id"

  attribute {
    name = "book_id"
    type = "S"
  }

  attribute {
    name = "genre"
    type = "S"
  }

  attribute {
    name = "upload_date"
    type = "S"
  }

  # Índice para buscar libros por género
  global_secondary_index {
    name            = "genre-upload-index"
    hash_key        = "genre"
    range_key       = "upload_date"
    projection_type = "ALL"
  }
}

# Tabla de progreso de lectura por usuario
resource "aws_dynamodb_table" "reading_progress" {
  name         = "${var.project_name}-reading-progress-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "book_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "book_id"
    type = "S"
  }
}
