variable "name" {
}

variable "container_task_definition" {
  
  type        = list(object({
    name                  = string
    image                 = string
    image_tag             = string
    privileged            = bool
    port                  = number
    environment_variables = map(string)
    secrets               = map(string)
    ssm                   = map(string)
  }))
}

variable "container_task_volumes" {
  type        = list(object({
    add_to         = list(string)
    container_path = string
    read_only      = bool
    name           = string
    host_path      = string
  }))
  default     = []
}

### ECS service variables
variable "auto_scaling_group_arn" {
}

variable "desired_count" {
  
}

variable "fargate_enabled" {
  
}

variable "log_retention_in_dayst" {
  
}

variable "ecs_type" {
  
}

variable "memory" {
  
}

variable "cpu" {
  
}

variable "execution_role_arn" {
  
}

variable "task_role_arn" {
  
}

variable "enable_code_deploy" {
default = false
}

variable "cluster" {
  
}

variable  "launch_type" {
  
}

variable  "enable_ecs_execute_command" {
default = false
}

variable  "target_group_arn" {
  
}

variable  "container_port" {
  
}

variable  "subnets" {
  
}

variable  "fargate_enabled" {
  dafault = false
}

variable  "assign_public_ip" {
  
}

variable  "security_groups" {
  
}

variable  "enable_code_deploy" {
  
}
variable  "lb_enable" {
  
}
variable  "max_capacity" {
  
}
variable  "min_capacity" {
  
}
variable  "scaling_cpu_target_value" {
  
}
variable  "scaling_memory_target_value" {
  
}
variable  "cpu_scale_in_cooldown" {
  
}
variable  "memory_scale_in_cooldown" {
  
}


variable  "cpu_scale_out_cooldown" {
  
}

variable  "memory_scale_out_cooldown" {
  
}
