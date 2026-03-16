variable "name" {
  description = "Name of the REST API"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
  type        = string
}

variable "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function (used in API Gateway integration)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function (used for permission)"
  type        = string
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}
