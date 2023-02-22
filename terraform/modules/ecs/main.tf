##########################
# Cloudwatch Log Group
########################
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  for_each = {for task in var.container_task_definition: task.name => task}

  name              = "${var.fargate_enabled ? "fargate" : "ecs"}/${var.name}-${each.value["name"]}"
  retention_in_days = var.log_retention_in_days

}

###########################################
# ECS Task Definition
###########################################

resource "random_string" "this" {
  length  = 5
  special = false
  upper   = false
  lower   = true
  number  = true
}

resource "aws_ecs_task_definition" "td" {
  family                   = "${var.name}-${resource.random_string.this.result}"
  container_definitions    = jsonencode(local.container_definition)
  requires_compatibilities = [var.launch_type]
  network_mode             = "bridge"
  execution_role_arn = aws_iam_role.task_role.arn
  task_role_arn = aws_iam_role.task_role.arn

  dynamic "volume" {
    for_each = {for task in var.container_task_volumes: task.name => task}
    content {
      name      = volume.value["name"]
      host_path = volume.value["host_path"]
    }
  }
}

###########################################
# ECS Service
###########################################
resource "aws_ecs_service" "svc" {
  count = var.enable_code_deploy ? 0 : 1

  name            = "${var.name}-svc"
  cluster         = var.cluster
  task_definition = aws_ecs_task_definition.td.arn
  desired_count   = var.desired_count
  # launch_type     = var.launch_type
  enable_execute_command = var.enable_ecs_execute_command

  dynamic "load_balancer" {
    for_each = var.lb_enable ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  # capacity_provider_strategy {
  #     capacity_provider = var.capacity_provider
  #     weight            = 1
  #     base              = 0
  #   }
  #network_configuration {
  #  subnets          = var.subnets
  #  assign_public_ip = var.fargate_enabled && var.assign_public_ip
  #  security_groups  = var.security_groups
  #}

  depends_on = [
    aws_ecs_task_definition.td
  ]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_iam_instance_profile" "ecs" {
  name  = "ecs-${var.name}-${data.aws_region.current.name}"
  role  = aws_iam_role.ecs.name
}

resource "aws_iam_role" "ecs" {
  name  = "ecs-${var.name}-${data.aws_region.current.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_ssm" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "ecs_ecs" {
  role       = aws_iam_role.ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_launch_template" "lt" {
  name_prefix = "${var.name}-tmplt"
  image_id = data.aws_ami.ecs_ami.id
  instance_type = "t2.micro"
  vpc_security_group_ids = var.security_groups
  iam_instance_profile {
    name = resource.aws_iam_instance_profile.ecs.name
  }
  # User data script to run on instances at launch
  user_data =base64encode(var.user_data)
  lifecycle {
    ignore_changes = [
      instance_type,
    ]
  }

}

resource "aws_autoscaling_group" "asg" {
  name = "${var.name}-asg"
  launch_template {
    id = aws_launch_template.lt.id
    version = "$Latest"
  }
  protect_from_scale_in = false
  vpc_zone_identifier = var.subnets
  max_size = 1
  min_size = 1
  desired_capacity = 1
  termination_policies = ["OldestInstance"]
  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}


