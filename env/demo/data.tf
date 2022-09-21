# Get current region
data "aws_region" "current" {}

# Get current account id
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}
