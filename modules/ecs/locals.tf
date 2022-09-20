locals {
  container_definition = [for task in var.container_task_definition:{
    name       = "${task.name}-task"
    image      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${task.image}:${task.image_tag}"
    essential  = true
    privileged = task.privileged

    portMappings = [{
      containerPort = task.port
      hostPort      = task.port
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options   = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_log_group[task.name].name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = task.name
      }
    }

    environment = [for key in keys(task.environment_variables) :{
      name  = key
      value = lookup(task.environment_variables, key)
    }]

    secrets = concat([for key in keys(task.ssm) :{
      name      = key
      valueFrom = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${replace(lookup(task.ssm, key), "/^//", "")}"
    }], [for key in keys(task.secrets) :{
      name      = key
      valueFrom = "${lookup(data.aws_secretsmanager_secret.task_secret, split(":",lookup(task.secrets, key))[0]).arn}${
      length(split(":", lookup(task.secrets, key))) >= 2 ?
        trimprefix(lookup(task.secrets, key), split(":", lookup(task.secrets, key))[0]):
        ""
      }"
    }])

    cpu         = 0
    mountPoints = [for volume in var.container_task_volumes: {
      sourceVolume = volume.name,
      containerPath = volume.container_path
    } if contains(volume.add_to, task.name)]
    volumesFrom = []
  }]
}