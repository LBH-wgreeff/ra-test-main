resource "aws_ecs_cluster" "abc" {
  name = "cluster"
}

resource "aws_ecs_service" "service" {
  name            = "ecs"
  cluster         = aws_ecs_cluster.cba.id
  task_definition = "${aws_ecs_task_definition.ecs_task_definition.family}:${aws_ecs_task_definition.ecs_task_definition.revision}"
  launch_type     = "EC2"
  desired_count   = 1

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = var.application
    container_port   = 8080
  }

  network_configuration {
    subnets         = "subnet-0b7e69f19e01efd45"
    security_groups = "[aws_security_group.sg.id]"
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family = "name"

  container_definitions = <<EOF
[
  {
    "name": "myapp",
    "image": "${aws_ecr_repository.ecr_repository.repository_url}:${var.ecr_tag}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ],
    "cpu": 0,
    "mountPoints" : [],
    "volumesFrom" : [],
    "environment" : [
      {
        "name": "DB_HOST",
        "value": "mydbhost"
      },
      {
        "name": "DB_NAME",
        "value": "mydb"
      },
      {
        "name": "DB_USER",
        "value": "admin"
      },
      {
        "name": "DB_Password",
        "value": "mypassword"
      }
    ]
  }
]
EOF

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.example.arn
  task_role_arn            = aws_iam_role.example.arn
}

data "aws_vpc" "default" {
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_security_group" "sg" {
  name        = "sg1"
  vpc_id      = data.aws_vpc.default.name
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description     = "description"
    from_port       = "Any"
    to_port         = "Any"
    protocol        = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

data "aws_subnets" "example" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.default]
  }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "5.1.0"

  identifier = "mydb"

  engine                = "postgres"
  engine_version        = "14.3"
  instance_class        = "db.t3.small"
  major_engine_version  = "14"
  family                = "postgres14"

  username               = "admin"
  password               = "mypassword"
  port                   = 6432
  db_name                = var.db_name
  create_random_password = false

  multi_az               = false
  subnet_ids             = data.aws_subnets.example.ids
  create_db_subnet_group = true
  db_subnet_group_name   = "rds-subnet-group"

  vpc_security_group_ids = [aws_security_group.sg]

  maintenance_window        = "Mon:11:00-Mon:13:00"
  backup_window             = "14:00-16:00"
  publicly_accessible       = true
  backup_retention_period   = 30
  create_db_parameter_group = false
  monitoring_interval       = 0
  storage_encrypted         = false
  skip_final_snapshot       = true
  deletion_protection       = false
}



module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.6.1"

  name               = "lb"
  load_balancer_type = "application"
  internal           = true
  vpc_id             = data.aws_vpc.default.id
  subnets            = [data.aws_subnets.example.ids]
  security_groups    = [aws_security_group.sg.id]
  target_groups = [
    {
      name             = "tg"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"

      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = 8080
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 20
        protocol            = "HTTP"
        matcher             = "200-302"
      }

      load_balancing_algorithm_type = "round_robin"
      slow_start                    = 0
      stickiness = {
        stickiness      = false
        type            = "lb_cookie"
        cookie_name     = null
        cookie_duration = null
      }
    }
  ]
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  idle_timeout                     = 60
  enable_cross_zone_load_balancing = true
  enable_http2                     = true
  drop_invalid_header_fields       = false
  load_balancer_delete_timeout     = "5m"
  enable_deletion_protection       = false
}

resource "aws_iam_role" "example" {
  name = "r"
  path = "/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ecs-tasks.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "example2" {
  role       = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}