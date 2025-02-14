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

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "satclus"

}


resource "aws_ecs_service" "satispay" {
  name            = "satispay"
  cluster         = module.ecs.cluster_id
  task_definition = resource.aws_ecs_task_definition.public.arn
  desired_count   = 1

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
