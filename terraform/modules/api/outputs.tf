# terraform/modules/api/outputs.tf

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}"
}

output "lambda_backend_arn" {
  description = "Backend Lambda ARN"
  value       = aws_lambda_function.backend.arn
}

output "lambda_backend_role_arn" {
  description = "Backend Lambda IAM Role ARN"
  value       = aws_iam_role.lambda_backend.arn
}

output "cloudfront_private_key_secret_arn" {
  description = "Secrets Manager ARN for CloudFront private key"
  value       = aws_secretsmanager_secret.cloudfront_private_key.arn
}


