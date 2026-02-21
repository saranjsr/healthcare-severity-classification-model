resource "aws_cloudwatch_event_rule" "sagemaker_trigger" {
  name        = "sagemaker-pipeline-trigger-tf"
  description = "Triggers SageMaker pipeline based on SNS event"
  event_pattern = jsonencode({
    source      = ["custom.sns"]
    "detail-type" = ["SNS Notification"]
    detail = {
      topicArn = [aws_sns_topic.lambda_trigger_topic.arn]
    }
  })
}

resource "aws_iam_role" "eventbridge_sagemaker_role" {
  name = "eventbridge-sagemaker-role-tf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_sagemaker_policy" {
  name = "sagemaker-execution-policy-tf"
  role = aws_iam_role.eventbridge_sagemaker_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sagemaker:StartPipelineExecution",
        Resource = "arn:aws:sagemaker:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:pipeline/severity-classification-pipeline-tf"
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "sagemaker_pipeline_target" {
  rule      = aws_cloudwatch_event_rule.sagemaker_trigger.name
  target_id = "StartSageMakerPipelineTf"
  arn       = "arn:aws:sagemaker:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:pipeline/severity-classification-pipeline-tf"
  role_arn  = aws_iam_role.eventbridge_sagemaker_role.arn
}
