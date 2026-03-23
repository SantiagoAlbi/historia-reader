# terraform/modules/observability/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "state_machine_arn" {
  type = string
}

variable "lambda_backend_arn" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}
