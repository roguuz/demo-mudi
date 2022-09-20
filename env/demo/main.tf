###########################################
# VPC
###########################################
module vpc {
  source = "terraform-aws-modules/vpc/aws"
  name = "demo-boundless"
  version = "3.2.0"
  cidr = "10.0.0.0/16"
  azs = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]
  public_subnets =  ["10.0.4.0/24","10.0.5.0/24","10.0.6.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  public_subnet_tags = {
      "Name" = "demo-boundless-public"
  }
  private_subnet_tags = {
      "Name" = "demo-boundless-private"
  }
}

###########################################
# SECURITY GROUPS
###########################################
module "sg-ecs" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "demo-ecs-sg"
  vpc_id      = module.vpc.vpc_id
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 32768
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "sg-alb" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "demo-alb-sg"
  vpc_id      = module.vpc.vpc_id
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

###########################################
# ECS CLUSTER
###########################################

module "ecs-fargate" {
  source = "terraform-aws-modules/ecs/aws"
  cluster_name = "demo-boundless"
  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/cluster/demo-boundless"
      }
    }
  }
}

###########################################
# ECR 
###########################################
resource "aws_ecr_repository" "one" {
  name = "boundless-demo"

  image_scanning_configuration {
    scan_on_push = false
  }
}


