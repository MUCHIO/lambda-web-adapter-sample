include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/dynamodb-table/aws?version=5.5.0"
}



inputs = {
  name         = "${include.root.locals.project_id}-${include.root.locals.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attributes = [
    { name = "PK", type = "S" },
    { name = "SK", type = "S" },
  ]
}
