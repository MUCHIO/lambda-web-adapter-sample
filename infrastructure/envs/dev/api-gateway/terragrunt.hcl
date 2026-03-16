include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Dependencies
dependency "lambda" {
  config_path = "../lambda"

  mock_outputs = {
    lambda_function_arn        = "arn:aws:lambda:us-west-2:123456789012:function:mock-handler"
    lambda_function_invoke_arn = "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-west-2:123456789012:function:mock-handler/invocations"
    lambda_function_name       = "mock-handler"
  }
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/api-gateway"
}

inputs = {
  name                       = "${include.root.locals.project_id}-${include.root.locals.environment}"
  lambda_function_arn        = dependency.lambda.outputs.lambda_function_arn
  lambda_function_invoke_arn = dependency.lambda.outputs.lambda_function_invoke_arn
  lambda_function_name       = dependency.lambda.outputs.lambda_function_name
  stage_name                 = include.root.locals.environment
}
