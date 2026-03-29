# VPC Module from Terraform Registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # No NAT Gateway - private instances have no internet access
  enable_nat_gateway = false
  enable_vpn_gateway = false

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags
  tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "Terraform"
  }

  public_subnet_tags = {
    Name = "${var.project_name}-public"
    Type = "public"
  }

  private_subnet_tags = {
    Name = "${var.project_name}-private"
    Type = "private"
  }
}
