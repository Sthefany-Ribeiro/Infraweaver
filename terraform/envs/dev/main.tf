terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "infraweaver-tfstate-020901022128"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    use_lockfile = true
    encrypt        = true
  }
}

provider "aws" {
  region = "us-west-2"
}

module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  cidr_block         = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b"]
}

module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = "t3.medium"
  desired_nodes      = 2
  min_nodes          = 1
  max_nodes          = 3
}

module "rds" {
  source = "../../modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
}