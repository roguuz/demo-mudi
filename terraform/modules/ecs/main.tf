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

resource "aws_ecs_task_definition" "td" {
  family                   = var.name
  container_definitions    = jsonencode(local.container_definition)
  requires_compatibilities = [var.launch_type]
  network_mode             = "awsvpc"
  memory                   = var.memory_limit
  cpu                      = var.cpu_limit
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
      container_name   = aws_ecs_task_definition.td.family
      container_port   = var.container_port
    }
  }

  capacity_provider_strategy {
      capacity_provider = resource.aws_ecs_capacity_provider.this.name
      weight            = 1
      base              = 0
    }
  network_configuration {
    subnets          = var.subnets
    assign_public_ip = var.fargate_enabled && var.assign_public_ip
    security_groups  = var.security_groups
  }

  depends_on = [
    aws_ecs_task_definition.td
  ]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_launch_template" "this" {
  name_prefix = "${var.name}-tmplt"
  image_id = data.aws_ami.ecs_ami.id
  instance_type = "t2.micro"

  # User data script to run on instances at launch
  user_data = <<-EOF
    #!/bin/bash
    echo 'ECS_CLUSTER=${var.cluster}' >> /etc/ecs/ecs.config
  EOF

  # Block device mapping
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp2"
      delete_on_termination = true
    }
  }

  # Network interfaces
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination = true
    security_groups = [var.security_groups]
  }

}


resource "aws_ecs_capacity_provider" "this" {
  name = "${var.name}-cap-prv"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this.arn
    
    managed_termination_protection = "DISABLED"
    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 2
      status = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name = "${var.name}-asg"
  launch_template {
    id = aws_launch_template.this.id
    version = "$Latest"
  }
  max_size = 1
  min_size = 1
  desired_capacity = 0
  termination_policies = ["OldestInstance"]
}


