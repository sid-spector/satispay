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
  name            = "satispay-test"
  cluster_version = "1.32"
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

}



################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr =  "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]


  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}