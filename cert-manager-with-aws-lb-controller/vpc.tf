locals {
  vpc_name = "cert-manager-aws-alb-ctrl"
  vpc_cidr = "10.0.0.0/16"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = local.vpc_name
  cidr = local.vpc_cidr

  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b",
    "${var.aws_region}c"
  ]

  private_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 1),
    cidrsubnet(local.vpc_cidr, 8, 2),
    cidrsubnet(local.vpc_cidr, 8, 3)
  ]

  public_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 4),
    cidrsubnet(local.vpc_cidr, 8, 5),
    cidrsubnet(local.vpc_cidr, 8, 6)
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  public_subnet_tags = {
    "Name"                   = "${local.vpc_name}-public-subnet"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "Name"                            = "${local.vpc_name}-private-subnet"
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name = local.vpc_name
  }
}
