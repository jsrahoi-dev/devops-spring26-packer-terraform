# Terraform configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# Data source to get current public IP
data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com"
}

# Local variables
locals {
  my_ip_detected = chomp(data.http.my_public_ip.response_body)
  my_ip_final    = var.my_ip != "" ? var.my_ip : local.my_ip_detected
}

# AWS Key Pair from SSH public key
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-deployer-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name    = "${var.project_name}-deployer-key"
    Project = var.project_name
  }
}

# Bastion Host in Public Subnet
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type              = var.instance_type
  subnet_id                  = module.vpc.public_subnets[0]
  vpc_security_group_ids     = [aws_security_group.bastion_sg.id]
  key_name                   = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.project_name}-bastion"
    Project = var.project_name
    Type    = "bastion"
  }
}

# Private EC2 Instances
resource "aws_instance" "private" {
  count = var.private_instance_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.project_name}-private-${count.index + 1}"
    Project = var.project_name
    Type    = "private"
    Index   = count.index + 1
  }
}
