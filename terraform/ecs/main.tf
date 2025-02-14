terraform {
  backend "s3" {
    bucket = "tfstate-aws-sid"
    key    = "terragrunt.tfstate"
    region = "eu-west-1"
    kms_key_id = "arn:aws:kms:eu-west-1:296062560327:key/bc16cb9b-9a9b-4d10-b765-6480df764563"
  }
}


provider "aws" {
  region  = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::296062560327:role/terraformAdminRole"
  }
}


locals {
  name = "satclus"

  user_data = <<-EOT
    #!/bin/bash

    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    ECS_LOGLEVEL=debug
    ECS_ENABLE_TASK_IAM_ROLE=true
    EOF
  EOT
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = local.name

    cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }

  autoscaling_capacity_providers = {
    one = {
      auto_scaling_group_arn         = module.autoscaling.autoscaling_group_arn
     managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }

    }
  }

}


resource "aws_ecs_service" "satispay" {
  name            = "satispay"
  cluster         = module.ecs.cluster_id
  task_definition = resource.aws_ecs_task_definition.public.arn
  desired_count   = 1

  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    # On-demand instances
    ex_1 = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["one"].name
      weight            = 1
      base              = 1
    }
  }

  load_balancer {
    target_group_arn = module.alb.target_groups.public.arn
    container_name   = "public"
    container_port   = 80
  }

}

resource "aws_ecs_task_definition" "public" {
  family = "statiscoso"
  task_role_arn = aws_iam_role.ecr_read_role.arn
  container_definitions = file("../../containersDefinition/containersDefinition.json")
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "satispay"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name = "satispay"

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets


  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "public"
      }
    }
  }

  target_groups = {
    public = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "instance"
      create_attachment = false
    }
  }
}

resource "aws_ecr_repository" "proxy" {
  name                 = "proxy"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "app" {
  name                 = "app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_role" "ecr_read_role" {
  name = "ecr-read-role"
  managed_policy_arns = [ resource.aws_iam_policy.ecr_read_policy.arn ]
  assume_role_policy = jsonencode(
  {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_read_policy" {
  name        = "ecr-read-policy"
  

  policy = <<EOT
{
 "Version": "2012-10-17",
"Statement" : [
  {
    "Effect" : "Allow",
    "Action" : [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ],
    "Resource": "${aws_ecr_repository.proxy.arn}, ${resource.aws_ecr_repository.app.arn}"
  },
  {
    "Effect": "Allow",
    "Action" : "ecr:GetAuthorizationToken",
    "Resource" : "*"
  }
]
}
EOT
  
}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}


module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"
  name = "ex_1"
  instance_type              = "t3.micro"
  use_mixed_instances_policy = false
  mixed_instances_policy     = {}
  min_size = 1
  max_size = 3
   create                 = true
  create_launch_template = true
  vpc_zone_identifier = module.vpc.private_subnets
  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
   health_check_type   = "EC2"
   user_data                       = base64encode(local.user_data)
  }