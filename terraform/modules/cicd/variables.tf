# terraform/modules/cicd/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_connection_arn" {
  type        = string
  description = "ARN of the CodeStar GitHub connection"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in format owner/repo-name"
}

variable "github_branch" {
  type    = string
  default = "main"
}
