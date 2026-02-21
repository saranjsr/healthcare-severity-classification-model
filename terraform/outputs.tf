# output "public_subnet_ids" {
#   value = aws_vpc.main.public_subnets
# }

# output "private_subnet_ids" {
#   value = module.vpc.private_subnets
# }

output "sagemaker_s3_bucket_name" {
  value = aws_s3_bucket.pipeline_bucket.bucket
}

output "sagemaker_iam_role_name" {
  value = aws_iam_role.sagemaker_role.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.lambda_trigger_topic.arn
}

output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.severity_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.severity_stage.stage_name}/ml-model-test"
}

