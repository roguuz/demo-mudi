output "task_definition_arn" {
  value       = aws_ecs_task_definition.td.arn
}

output "asg_arn" {
  value       = aws_autoscaling_group.asg.arn
}
