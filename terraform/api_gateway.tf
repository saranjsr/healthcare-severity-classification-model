resource "aws_iam_role" "apigw_cloudwatch_role" {
  name = "apigw-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "apigw_cloudwatch_policy" {
  name   = "apigw-cloudwatch-policy"
  role   = aws_iam_role.apigw_cloudwatch_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}


# Create REST API Gateway
resource "aws_api_gateway_rest_api" "severity_api" {
  name        = "severity-classification-tf-api"
  description = "API Gateway to trigger severity SageMaker model deployment"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "deploy_resource" {
  rest_api_id = aws_api_gateway_rest_api.severity_api.id
  parent_id   = aws_api_gateway_rest_api.severity_api.root_resource_id
  path_part   = "ml-model-test"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.severity_api.id
  resource_id   = aws_api_gateway_resource.deploy_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integrate API Gateway with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.severity_api.id
  resource_id             = aws_api_gateway_resource.deploy_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.model_test_lambda.invoke_arn
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.model_test_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.severity_api.execution_arn}/*/*"
}

# Deploy the API
resource "aws_api_gateway_deployment" "severity_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.severity_api.id

  triggers = {
    redeployment = sha1(jsonencode({
      method = aws_api_gateway_method.post_method.id,
      integration = aws_api_gateway_integration.lambda_integration.id
    }))
  }
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  # name              = "/aws/api-gateway/severity-classification-tf-api"
  name = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.severity_api.id}/dev"
  retention_in_days = 14
}

resource "aws_api_gateway_stage" "severity_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.severity_api.id
  deployment_id = aws_api_gateway_deployment.severity_deployment.id
}

resource "aws_api_gateway_method_settings" "cw" {
  rest_api_id = aws_api_gateway_rest_api.severity_api.id
  stage_name  = aws_api_gateway_stage.severity_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
    data_trace_enabled = true
  }
}

# Integration response
resource "aws_api_gateway_integration_response" "integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.severity_api.id
  resource_id = aws_api_gateway_resource.deploy_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"
  selection_pattern = ""

  response_templates = {
    "application/json" = ""
  }
}

# Method response
resource "aws_api_gateway_method_response" "method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.severity_api.id
  resource_id = aws_api_gateway_resource.deploy_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
  depends_on = [aws_api_gateway_integration.lambda_integration]
}