# terraform/modules/ingestion/outputs.tf

output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.ingestion.arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for ingestion notifications"
  value       = aws_sns_topic.ingestion_notifications.arn
}
