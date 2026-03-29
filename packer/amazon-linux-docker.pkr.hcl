packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Data source to find latest Amazon Linux 2023 AMI
data "amazon-ami" "amazon_linux_2023" {
  filters = {
    name                = "al2023-ami-*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.aws_region
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = "${var.ami_name_prefix}-${local.timestamp}"
}

# Builder configuration
source "amazon-ebs" "amazon_linux" {
  region        = var.aws_region
  source_ami    = data.amazon-ami.amazon_linux_2023.id
  instance_type = var.instance_type
  ssh_username  = var.ssh_username
  ami_name      = local.ami_name

  tags = {
    Name        = local.ami_name
    Created     = timestamp()
    Builder     = "Packer"
    Purpose     = "DevOps Spring 2026 Assignment"
    BaseOS      = "Amazon Linux 2023"
    HasDocker   = "true"
  }
}

# Build configuration
build {
  sources = ["source.amazon-ebs.amazon_linux"]

  # Update system packages
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo yum update -y"
    ]
  }

  # Install Docker
  provisioner "shell" {
    inline = [
      "echo 'Installing Docker...'",
      "sudo yum install -y docker",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -a -G docker ec2-user"
    ]
  }

  # Install docker-compose
  provisioner "shell" {
    inline = [
      "echo 'Installing docker-compose...'",
      "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "docker-compose --version || echo 'docker-compose installation complete'"
    ]
  }

  # Set up SSH key
  provisioner "file" {
    source      = pathexpand(var.ssh_public_key_path)
    destination = "/tmp/authorized_keys"
  }

  provisioner "shell" {
    inline = [
      "echo 'Setting up SSH authorized keys...'",
      "mkdir -p /home/ec2-user/.ssh",
      "cat /tmp/authorized_keys >> /home/ec2-user/.ssh/authorized_keys",
      "chmod 700 /home/ec2-user/.ssh",
      "chmod 600 /home/ec2-user/.ssh/authorized_keys",
      "chown -R ec2-user:ec2-user /home/ec2-user/.ssh",
      "rm /tmp/authorized_keys"
    ]
  }

  # Verify installations
  provisioner "shell" {
    inline = [
      "echo 'Verifying installations...'",
      "docker --version",
      "docker-compose --version",
      "echo 'SSH key lines in authorized_keys:'",
      "wc -l /home/ec2-user/.ssh/authorized_keys"
    ]
  }

  # Post-processor to display AMI ID
  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}
