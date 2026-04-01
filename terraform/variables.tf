variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "devops-spring26"
}

variable "ami_id" {
  description = "AMI ID from Packer build (required)"
  type        = string

  validation {
    condition     = can(regex("^ami-", var.ami_id))
    error_message = "AMI ID must start with 'ami-'"
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_instance_count" {
  description = "Number of private EC2 instances to create"
  type        = number
  default     = 6

  validation {
    condition     = var.private_instance_count > 0 && var.private_instance_count <= 10
    error_message = "Private instance count must be between 1 and 10"
  }
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_ed25519_jsrahoi-dev.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioner connections"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "my_ip" {
  description = "Your public IP address for SSH access (leave empty for auto-detect)"
  type        = string
  default     = ""
}
