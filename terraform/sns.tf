resource "aws_sns_topic" "lambda_trigger_topic" {
  name = "healthcare-classification-lambda-retrain-topic"
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrain_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.lambda_trigger_topic.arn
}

resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.lambda_trigger_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.retrain_lambda.arn
}
