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
  ingress_with_source_security_group_id = [
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      source_security_group_id = module.sg-alb.security_group_id
    },
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
  security_groups    = [module.sg-alb.security_group_id]

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
  cluster = module.ecs-cluster.cluster_name
  name = "demo-boundless"
  launch_type = "FARGATE"
  fargate_enabled = true
  lb_enable   = true
  target_group_arn = module.alb.target_group_arns
  assign_public_ip = true
  subnets = [module.vpc.private_subnets[0],module.vpc.private_subnets[1],module.vpc.private_subnets[2]]
  security_groups = [module.sg-ecs.security_group_id]
  cpu_limit           = 512
  memory_limit         = 512
  desired_count   = 1
  max_capacity = 5
  min_capacity = 1
  scaling_memory_target_value = 90  
  scaling_cpu_target_value = 70
  memory_scale_out_cooldown = 300
  memory_scale_in_cooldown = 120
  cpu_scale_out_cooldown = 300
  cpu_scale_in_cooldown = 120
  log_retention_in_days = 1
  execution_role_arn = aws_iam_role.task-role.arn
  task_role_arn = aws_iam_role.task-role.arn

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
}