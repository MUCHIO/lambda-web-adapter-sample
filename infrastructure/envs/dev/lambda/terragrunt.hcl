include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/lambda/aws?version=8.5.0"
}

# Dependencies
dependency "dynamodb" {
  config_path = "../dynamodb"

  mock_outputs = {
    dynamodb_table_id  = "mock"
    dynamodb_table_arn = "arn:aws:dynamodb:us-west-2:123456789012:table/mock"
  }
}

dependency "ecr" {
  config_path = "../ecr"

  mock_outputs = {
    repository_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com/mock"
    repository_arn = "arn:aws:ecr:us-west-2:123456789012:repository/mock"
  }
}

inputs = {
  function_name = "${include.root.locals.project_id}-${include.root.locals.environment}"
  description   = "Lambda Web Adapter sample - ${include.root.locals.environment}"

  # Container image deployment
  # create_package must be false when using container images;
  # otherwise the module tries to build a zip and crashes with
  # "Unsupported source_path item: None".
  create_package = false
  package_type   = "Image"
  image_uri      = "${dependency.ecr.outputs.repository_url}:latest"

  # image_config for Lambda Web Adapter
  # The container must listen on the port specified by PORT env var
  environment_variables = {
    PORT        = "8080"
    ENVIRONMENT = include.root.locals.environment
    TABLE_NAME  = dependency.dynamodb.outputs.dynamodb_table_id
  }

  memory_size = 512
  timeout     = 30

  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      resources = [
        dependency.dynamodb.outputs.dynamodb_table_arn,
        "${dependency.dynamodb.outputs.dynamodb_table_arn}/index/*",
      ]
    }
  }

  # Allow ECR image pull
  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = dependency.ecr.outputs.repository_arn
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })

  create_lambda_function_url = false
}
