### NLB ###

data "aws_subnets" "subnets_ids" {
  filter {
    name   = "vpc-id" 
    values = ["vpc-a961d1d2"]
  }
}

resource "aws_lb" "nlb" {
  name               = "backend-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnets.subnets_ids.ids

  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

### VPC LINK

resource "aws_api_gateway_vpc_link" "vpc_link" {
  name        = "vpc-link-backend"
  target_arns = [aws_lb.nlb.arn]
}

### API GTW ###

resource "aws_api_gateway_rest_api" "api" {
  name = "api-gateway-hackaton"
}

resource "aws_api_gateway_resource" "resource-movie" {
  path_part   = "movie"
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_method" "method-movie-get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource-movie.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "method-movie-get-integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource-movie.id
  http_method = aws_api_gateway_method.method-movie-get.http_method

  request_templates = {
    "application/json" = ""
    "application/xml"  = "#set($inputRoot = $input.path('$'))\n{ }"
  }

  request_parameters = {
    "integration.request.header.X-Authorization" = "'static'"
    "integration.request.header.X-Foo"           = "'Bar'"
  }

  type                    = "HTTP"
  uri                     = "https://www.google.de"
  integration_http_method = "GET"
  passthrough_behavior    = "WHEN_NO_MATCH"
  content_handling        = "CONVERT_TO_TEXT"

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.vpc_link.id
}