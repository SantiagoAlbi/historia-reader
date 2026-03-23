# terraform/modules/cicd/outputs.tf

output "pipeline_name" {
  description = "CodePipeline pipeline name"
  value       = aws_codepipeline.main.name
}

output "artifacts_bucket" {
  description = "S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.artifacts.id
}
