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

###############################
# Application Load Balancer
###############################
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "demo-boundless"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = [module.vpc.public_subnets[0],module.vpc.public_subnets[1],module.vpc.public_subnets[2]]
  security_groups    = [module.sg_alb.security_group_id]

  target_groups = [
    {
      name_prefix      = "demo-boundless-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
}

###########################################
# ECS CLUSTER
###########################################

module "ecs-cluster" {
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
resource "aws_ecr_repository" "ecr" {
  name = "boundless-demo"

  image_scanning_configuration {
    scan_on_push = false
  }
}

#############################
# ECS Service
#############################

module "ecs-services" {
  source = "../../modules/ecs"
  lb_enable                   = true
  fargate_enabled = true
  assign_public_ip = true
  
  cpu_limit           = 512
  memory_limit         = 512
  desired_count   = 1
  container_task_definition = [
    {
      name       = "demo-boundless"
      privileged = false
      image      = "nginx"
      image_tag  = "latest"
      port       = 80
      environment_variables = {
      }
      # secrets = { 
      # }
      ssm     = {}
    }
  ]
  vpc_id              = module.vpc.vpc_id
  subnets = [module.vpc.private_subnets[0],module.vpc.private_subnets[1],module.vpc.private_subnets[2]]
}