# terraform/modules/database/outputs.tf

output "books_table_name" {
  description = "Books DynamoDB table name"
  value       = aws_dynamodb_table.books.name
}

output "books_table_arn" {
  description = "Books DynamoDB table ARN"
  value       = aws_dynamodb_table.books.arn
}

output "reading_progress_table_name" {
  description = "Reading progress DynamoDB table name"
  value       = aws_dynamodb_table.reading_progress.name
}

output "reading_progress_table_arn" {
  description = "Reading progress DynamoDB table ARN"
  value       = aws_dynamodb_table.reading_progress.arn
}
