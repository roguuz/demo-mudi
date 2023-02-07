###########################################
# VPC
###########################################
module vpc {
  source = "terraform-aws-modules/vpc/aws"
  name = local.name
  version = "3.2.0"
  cidr = "10.0.0.0/16"
  azs = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24","10.0.2.0/24"]
  public_subnets =  ["10.0.3.0/24","10.0.4.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  public_subnet_tags = {
      "Name" = "${local.name}-public"
  }
  private_subnet_tags = {
      "Name" = "${local.name}-private"
  }
}

###########################################
# SECURITY GROUPS
###########################################
module "sg-ecs" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "${local.name}-ecs-sg"
  vpc_id      = module.vpc.vpc_id
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  ingress_with_source_security_group_id = [
    {
      from_port   = 9000
      to_port     = 9000
      protocol    = "tcp"
      source_security_group_id = module.sg-alb.security_group_id
    },
  ]
}

module "sg-alb" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "${local.name}-alb-sg"
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

  name = local.name

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = [module.vpc.public_subnets[0],module.vpc.public_subnets[1]]
  security_groups    = [module.sg-alb.security_group_id]

  target_groups = [
    {
      name_prefix      = substr(local.name, 0, 5)
      backend_protocol = "HTTP"
      backend_port     = 8080
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
  cluster_name = local.name
  # cluster_configuration = {
  #   execute_command_configuration = {
  #     logging = "OVERRIDE"
  #     log_configuration = {
  #       cloud_watch_log_group_name = "/aws/ecs/cluster/${local.name}"
  #     }
  #   }
  # }
}

###########################################
# ECR 
###########################################
resource "aws_ecr_repository" "ecr" {
  name = local.name

  image_scanning_configuration {
    scan_on_push = false
  }
}

#############################
# ECS Service
#############################

module "ecs-service" {
  source = "../../modules/ecs"
  cluster = module.ecs-cluster.cluster_name
  name = local.name
  # launch_type = "EC2"
  lb_enable   = true
  container_port = 8080
  target_group_arn = module.alb.target_group_arns[0]
  assign_public_ip = true
  subnets = [module.vpc.private_subnets[0],module.vpc.private_subnets[1]]
  security_groups = [module.sg-ecs.security_group_id]
  cpu_limit           = 512
  memory_limit         = 1024
  desired_count   = 1
  log_retention_in_days = 0

  container_task_definition = [
    {
      name       = local.name
      privileged = false
      image      = local.name
      image_tag  = "latest"
      port       = 8080
      environment_variables = {
      }
      ssm     = {}
    }
  ]
}


###########EC2 Jenkins
module "sg-ssh" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "ssh"
  vpc_id      = module.vpc.vpc_id
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "sg-jenkins" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "jenkins"
  vpc_id      = module.vpc.vpc_id
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "tls_private_key" "jenkins" {
  algorithm = "RSA"
}

module "jenkins_key_pair" {
  source = "terraform-aws-modules/key-pair/aws"
  version = "1.0.1"

  key_name   = "jenkins_key"
  public_key = tls_private_key.jenkins.public_key_openssh
  create_key_pair = true
  depends_on = [tls_private_key.jenkins]
}

module "ec2-jenkins" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = local.name

  ami                    = "ami-00b8caf62fc9c2341"
  instance_type          = "t2.micro"
  key_name               = module.jenkins_key_pair.key_pair_key_name
  monitoring             = false
  vpc_security_group_ids = [module.sg-jenkins.security_group_id,module.sg-ssh.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
  user_data_base64 = base64encode(local.jenkins_user_data)
  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 20
      delete_on_termination = true
    },
  ]
}