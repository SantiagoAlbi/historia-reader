# terraform/modules/cdn/variables.tf

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "books_bucket_id" {
  description = "Books S3 bucket name"
  type        = string
}

variable "books_bucket_arn" {
  description = "Books S3 bucket ARN"
  type        = string
}

variable "frontend_bucket_id" {
  description = "Frontend S3 bucket name"
  type        = string
}
