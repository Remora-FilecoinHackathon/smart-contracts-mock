# TODO: Generalize variables
variable "aws_region" {
  description = "Region where resources are deployed"
  type = string
  default = "us-west-2"
}

data "aws_caller_identity" "current" {
  
}

variable "ecr_repo_name" {
    description = "Name of the ECR repository to store contract listener container in"
    type = string
    default = "remora"
}

variable "ecs_cluster_name" {
    description = "Name to use for the ECS cluster"
    type = string
    default = "event-listener-cluster"
}

variable "ecs_container_name" {
  description = "Name of the container to use in ECS"
  default = "remora"
}

variable "ecs_service_name" {
  description = "Name of the service to use in ECS"
  default = "event-listener-service"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type = string
  default = "remora"
}

variable "lambda_deployment_package_path" {
  description = "Path to the Lambda deployment package"
  default = "./remora.zip"
}

variable "task_defintion_family" {
  description = "Name of the family for ECS"
  default = "event-listener"
}

variable "sqs_queue_name" {
    description = "Name of the SQS queue"
    type = string
    default = "fil-reputation"
}

variable "subnet" {
    description = "ID of the subnet to deploy into"
    type = string
    default = "subnet-id"
}