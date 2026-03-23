# terraform/modules/observability/main.tf

resource "aws_cloudwatch_log_group" "lambda_backend" {
  name              = "/aws/lambda/${var.project_name}-backend-${var.environment}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda_validation" {
  name              = "/aws/lambda/${var.project_name}-validation-${var.environment}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda_metadata_extractor" {
  name              = "/aws/lambda/${var.project_name}-metadata-extractor-${var.environment}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda_thumbnail_generator" {
  name              = "/aws/lambda/${var.project_name}-thumbnail-generator-${var.environment}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda_catalog_register" {
  name              = "/aws/lambda/${var.project_name}-catalog-register-${var.environment}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/${var.project_name}-ingestion-${var.environment}"
  retention_in_days = 7
}
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Pipeline Executions"
          region = "us-east-1"
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/States", "ExecutionsStarted", "StateMachineArn", var.state_machine_arn],
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", var.state_machine_arn],
            ["AWS/States", "ExecutionsFailed", "StateMachineArn", var.state_machine_arn]
          ]
          annotations = {
            horizontal = []
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Pipeline Execution Time"
          region = "us-east-1"
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/States", "ExecutionTime", "StateMachineArn", var.state_machine_arn]
          ]
          annotations = {
            horizontal = []
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Backend Lambda Errors"
          region = "us-east-1"
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-backend-${var.environment}"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-backend-${var.environment}"]
          ]
          annotations = {
            horizontal = []
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Backend Lambda Duration"
          region = "us-east-1"
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-backend-${var.environment}"]
          ]
          annotations = {
            horizontal = []
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "pipeline_failures" {
  alarm_name          = "${var.project_name}-pipeline-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Pipeline ingestion failures detected"

  dimensions = {
    StateMachineArn = var.state_machine_arn
  }

  alarm_actions = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "backend_errors" {
  alarm_name          = "${var.project_name}-backend-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Backend Lambda errors exceeded threshold"

  dimensions = {
    FunctionName = "${var.project_name}-backend-${var.environment}"
  }

  alarm_actions = [var.sns_topic_arn]
}
