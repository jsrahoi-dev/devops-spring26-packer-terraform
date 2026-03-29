variable "aws_region" {
  type    = string
  default = "us-east-1"
  description = "AWS region to build AMI in"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
  description = "Instance type for Packer builder"
}

variable "ssh_username" {
  type    = string
  default = "ec2-user"
  description = "SSH username for Amazon Linux"
}

variable "ami_name_prefix" {
  type    = string
  default = "devops-packer-docker"
  description = "Prefix for AMI name"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519_jsrahoi-dev.pub"
  description = "Path to SSH public key to embed in AMI"
}
