resource "aws_cloudwatch_metric_alarm" "severity_age_ks_pvalue_alarm" {
  alarm_name          = "severity_age_ks_pvalue_alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0.05
  treat_missing_data  = "missing"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.lambda_trigger_topic.arn]
  metric_name = "KS_PValue"
  namespace   = "SageMaker/ModelMonitoring"
  statistic   = "Average"
  period      = 300

  dimensions = {
    Feature = "Age"
  }
}
