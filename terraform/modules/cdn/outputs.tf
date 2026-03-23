# terraform/modules/cdn/outputs.tf

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "key_group_id" {
  description = "CloudFront key group ID — usado por Lambda para firmar URLs"
  value       = aws_cloudfront_key_group.main.id
}
