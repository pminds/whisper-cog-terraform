# Create the VPC Link
resource "aws_api_gateway_vpc_link" "models_api_vpc_link" {
  name        = "models-api-vpc-link"
  target_arns = [aws_lb.models_loadbalancer.arn]
}

# Create the API Gateway REST API
resource "aws_api_gateway_rest_api" "models_api" {
  name               = "models-api"
  binary_media_types = ["*/*"]
}

# Create the proxy resource to catch all requests
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.models_api.id
  parent_id   = aws_api_gateway_rest_api.models_api.root_resource_id
  path_part   = "{proxy+}"
}

# Configure the integration to send requests to the ALB
resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.models_api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.models_api_vpc_link.id
  uri                     = "http://${aws_lb.models_loadbalancer.dns_name}:5000/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy" # Map the path parameter
  }
}

# Create the ANY method to forward requests to the ALB
resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id      = aws_api_gateway_rest_api.models_api.id
  resource_id      = aws_api_gateway_resource.proxy.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_method_response" "proxy_method_response" {
  rest_api_id = aws_api_gateway_rest_api.models_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Deploy the API Gateway to a stage
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.models_api.id
  description = "Deployment - ${timestamp()}"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.proxy_method
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.models_api.id
  stage_name    = "test"

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format          = "{\"requestId\":\"$context.requestId\",\"ip\":\"$context.identity.sourceIp\",\"httpMethod\":\"$context.httpMethod\",\"resourcePath\":\"$context.resourcePath\",\"status\":\"$context.status\",\"protocol\":\"$context.protocol\",\"responseLength\":\"$context.responseLength\"}"
  }
}

# API Key
resource "aws_api_gateway_api_key" "api_key_customer_test" {
  name        = "customer-test"
  description = "API Key for testing basic HTTP server"
  enabled     = true
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "default_usage_plan" {
  name        = "default-usage-plan"
  description = "Default usage plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.models_api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }
}

# Associate Usage Plan with API Key
resource "aws_api_gateway_usage_plan_key" "default_usage_plan_customer_test" {
  usage_plan_id = aws_api_gateway_usage_plan.default_usage_plan.id
  key_id        = aws_api_gateway_api_key.api_key_customer_test.id
  key_type      = "API_KEY"
}

resource "aws_api_gateway_method_settings" "api_settings" {
  rest_api_id = aws_api_gateway_rest_api.models_api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled = true
    metrics_enabled    = true
    logging_level      = "INFO"
  }
}

# CloudWatch Log Group for API Gateway Logs
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.models_api.name}"
  retention_in_days = 365
}

# CloudWatch Logs Role for API Gateway
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "APIGatewayCloudWatchLogsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "apigateway.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}
