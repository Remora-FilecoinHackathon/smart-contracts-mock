# Lambda function
resource "aws_lambda_function" "smart_contract_executor" {
  filename = var.lambda_deployment_package_path
  function_name = var.function_name
  role = aws_iam_role.lambda_role.arn
  handler = "index.handler"
  runtime = "nodejs16.x"
  timeout = "180"
  environment {
    variables = {
        "LENDER_MANAGER" = "0xaE7eD725f5053471DB2Fc7254dBB2766615f7064"
        // TODO: MAKE THIS A SECRETS MANAGER CALL
        "PRIVATE_KEY"    = "key goes here"
    }
}
}

# SQS queue 
resource "aws_sqs_queue" "contract_event_queue" {
  name                      = var.sqs_queue_name
  delay_seconds             = 0
  max_message_size          = 1024
  message_retention_seconds = 18000
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled = true
  visibility_timeout_seconds = 180

  tags = {
    Environment = "production"
  }
  
  # TODO: Remove hardcoded values 
  policy = jsonencode({
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "__owner_statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "SQS:*",
      "Resource": "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.sqs_queue_name}"
    },
    {
      "Sid": "__sender_statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "SQS:SendMessage",
      "Resource": "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.sqs_queue_name}"
    },
    {
      "Sid": "__receiver_statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": [
        "SQS:ChangeMessageVisibility",
        "SQS:DeleteMessage",
        "SQS:ReceiveMessage"
      ],
      "Resource": "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.sqs_queue_name}"
    }
  ]
})
}

# ECR repository 
resource "aws_ecr_repository" "event_listener_ecr" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# ECS cluster
resource "aws_ecs_cluster" "event_listener_cluster" {
  name = var.ecs_cluster_name
}

# ECS service
resource "aws_ecs_service" "service" {
  name = var.ecs_service_name
  cluster = "${aws_ecs_cluster.event_listener_cluster.id}"
  task_definition = "${aws_ecs_task_definition.event_listener_task.arn}"
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [var.subnet]
    security_groups = [aws_security_group.sg.id]
    assign_public_ip = true
  }



}

# ECS task definition 
resource "aws_ecs_task_definition" "event_listener_task" {
  family = var.task_defintion_family
  cpu = 512
  memory = 2048
  

  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"



  container_definitions = jsonencode([
    {
      name = var.ecs_container_name
      cpu = 512
      memory = 2048
      image = "${aws_ecr_repository.event_listener_ecr.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8080
        }
      ]
      log_configuration = {
        log_driver = "awslogs"
            options = {
                awslogs-group = "${aws_cloudwatch_log_group.contract_events_group.arn}"
                awslogs-region = "${var.aws_region}"
                awslogs-stream-prefix = "${aws_cloudwatch_log_stream.contract_prefix}"
            }
        }
    }
  ])
}

# IAM policies 
## ECS needs SQS:SendMessage
resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_policy"
  description = "Policy to allow Lambda to write to CloudWatch Logs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
    ]
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name = "lambda_attachment"
  roles = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Security group
resource "aws_security_group" "sg" {
  name = "contract-listener-sg"
  vpc_id = "vpc-id"

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "contract_events_group" {
  name = "/ecs/contract-events-group"
}

resource "aws_cloudwatch_log_stream" "contract_prefix" {
  name   = "contract-events-prefix"
  log_group_name = aws_cloudwatch_log_group.contract_events_group.name
}
