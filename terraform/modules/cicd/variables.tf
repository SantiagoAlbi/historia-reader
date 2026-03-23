# terraform/modules/cicd/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in format owner/repo-name"
}
