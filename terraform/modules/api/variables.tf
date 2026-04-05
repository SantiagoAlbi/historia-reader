# terraform/modules/api/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "books_table_name" {
  type = string
}

variable "books_table_arn" {
  type = string
}

variable "reading_progress_table_name" {
  type = string
}

variable "reading_progress_table_arn" {
  type = string
}

variable "user_pool_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "books_bucket_id" {
  type = string
}
/*
variable "cloudfront_distribution_id" {
  type = string
}
*/
variable "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  type        = string
}

variable "cloudfront_key_pair_id" {
  description = "CloudFront public key pair ID for signed URLs"
  type        = string
}

variable "user_pool_client_id" {
  description = "Cognito User Pool Client ID for JWT audience validation"
  type        = string
}
