variable "name" {
}

variable "capacity_provider" {
  
}

variable "container_task_definition" {
  
  type        = list(object({
    name                  = string
    image                 = string
    image_tag             = string
    privileged            = bool
    port                  = number
    environment_variables = map(string)
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

variable "desired_count" {
  
}

variable "log_retention_in_days" {
  
}

variable "memory_limit" {
  
}

variable "cpu_limit" {
  
}

variable "cluster" {
  
}

variable  "launch_type" {
  default = "EC2"
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
  default = false
}

variable  "assign_public_ip" {
  
}

variable  "security_groups" {
  
}

variable  "enable_code_deploy" {
  default = false
}
variable  "lb_enable" {
  default = false
}
variable "user_data" {
  
}

variable "availability_zones" {
  
}