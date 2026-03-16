terraform_binary              = "tofu"
terraform_version_constraint  = ">= 1.11.5"
terragrunt_version_constraint = ">= 0.99.4"

locals {
  project_vars     = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project_id  = local.project_vars.locals.project_id
  aws_region  = local.region_vars.locals.aws_region
  environment = local.environment_vars.locals.environment
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "tfstate-tofu"
    key          = "${local.project_id}/${path_relative_to_include()}"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = {
      opentofu       = "true"
      environment    = "${local.environment}"
      project        = "${local.project_id}"
      CmBillingGroup = "${local.project_id}"
    }
  }
}
EOF
}
