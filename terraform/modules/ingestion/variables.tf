# terraform/modules/ingestion/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "books_bucket_id" {
  type = string
}

variable "books_bucket_arn" {
  type = string
}

variable "books_table_name" {
  type = string
}

variable "books_table_arn" {
  type = string
}
