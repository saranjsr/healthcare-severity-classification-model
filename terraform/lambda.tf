resource "aws_iam_role" "lambda_role" {
  name = "LambdaExecutionRoletf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = [
                    "lambda.amazonaws.com",
                    "apigateway.amazonaws.com"
                ]
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "LambdaExecutionPolicytf"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.tf_s3_pipeline}",
          "arn:aws:s3:::${var.tf_s3_pipeline}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateModel",
          "sagemaker:DescribeModel",
          "sagemaker:CreateEndpoint",
          "sagemaker:DescribeEndpoint",
          "sagemaker:UpdateEndpoint",
          "sagemaker:ListModelPackageGroups",
          "events:PutEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_fullaccess" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "sns_fullaccess" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# API Gateway

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.model_test_lambda.function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.severity_api.execution_arn}/*/*/*"
}

# Lambda Deployment for Model Approval
resource "aws_lambda_function" "approval_lambda" {
  function_name    = "severity-classification-approval-lt"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.10"
  filename        = "${path.module}/lambdas/model_approval.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/model_approval.zip")
  timeout         = 120
  tags = local.common_tags
}

# Lambda Deployment for Model Deployment
resource "aws_lambda_function" "deploy_lambda" {
  function_name    = "healthcare-severity-classification-model-lt"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.10"
  filename        = "${path.module}/lambdas/model_deploy.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/model_deploy.zip")
  timeout         = 900
  tags = local.common_tags
}

# Lambda to create model group
resource "aws_lambda_function" "create_modelgroup_lambda" {
  function_name    = "healthcare-severity-classification-modelgroup-lt"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.10"
  filename        = "${path.module}/lambdas/create_model_group.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/create_model_group.zip")
  timeout         = 120
  tags = local.common_tags
}

# Lambda to capture data
resource "aws_lambda_function" "data_capture_lambda" {
  function_name    = "healthcare-severity-classification-datacapture-lt"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.10"
  filename        = "${path.module}/lambdas/enable_data_capture.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/enable_data_capture.zip")
  timeout         = 600
  tags = local.common_tags
}

# Lambda for model retraining
resource "aws_lambda_function" "retrain_lambda" {
  function_name    = "healthcare-severity-classification-retrain-lt"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.10"
  filename        = "${path.module}/lambdas/model_retrain.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/model_retrain.zip")
  timeout         = 600
  tags = local.common_tags
}

# Lambda for test model
resource "aws_lambda_function" "model_test_lambda" {
  function_name    = "healthcare-severity-classification-model-test-lt"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.10"
  filename        = "${path.module}/lambdas/model_test.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/model_test.zip")
  timeout         = 600
  layers = [
    "arn:aws:lambda:eu-north-1:336392948345:layer:AWSSDKPandas-Python310:23"
  ]
  tags = local.common_tags
}

resource "aws_lambda_function" "check_s3_lambda" {
  function_name    = "healthcare-severity-classification-checks3-lt"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.10"
  filename        = "${path.module}/lambdas/s3_data_check.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/s3_data_check.zip")
  timeout         = 600
  tags = local.common_tags
}
