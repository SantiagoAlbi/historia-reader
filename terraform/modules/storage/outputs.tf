# terraform/modules/storage/outputs.tf

output "books_bucket_id" {
  description = "Books S3 bucket name"
  value       = aws_s3_bucket.books.id
}

output "books_bucket_arn" {
  description = "Books S3 bucket ARN"
  value       = aws_s3_bucket.books.arn
}

output "frontend_bucket_id" {
  description = "Frontend S3 bucket name"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "Frontend S3 bucket ARN"
  value       = aws_s3_bucket.frontend.arn
}
