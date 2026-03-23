# terraform/modules/cicd/outputs.tf

output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}
