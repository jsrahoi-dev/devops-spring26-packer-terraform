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
    Name      = local.ami_name
    Created   = timestamp()
    Builder   = "Packer"
    Purpose   = "DevOps Spring 2026 Assignment"
    BaseOS    = "Amazon Linux 2023"
    HasDocker = "true"
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

  # Install Prometheus node_exporter
  provisioner "shell" {
    inline = [
      "echo 'Installing Prometheus node_exporter...'",
      "cd /tmp",
      "curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz",
      "curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/sha256sums.txt",
      "sha256sum -c sha256sums.txt --ignore-missing",
      "tar xzf node_exporter-1.7.0.linux-amd64.tar.gz",
      "sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/",
      "sudo chmod +x /usr/local/bin/node_exporter",
      "rm -rf node_exporter-* sha256sums.txt"
    ]
  }

  # Create node_exporter systemd service
  provisioner "file" {
    content = <<-EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=ec2-user
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure
RestartSec=5

# Security hardening
NoNewPrivileges=true
ProtectHome=true
ProtectSystem=strict
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    destination = "/tmp/node_exporter.service"
  }

  # Enable and start node_exporter service
  provisioner "shell" {
    inline = [
      "echo 'Configuring node_exporter service...'",
      "sudo mv /tmp/node_exporter.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable node_exporter",
      "sudo systemctl start node_exporter",
      "sleep 5",
      "echo 'Verifying node_exporter is running...'",
      "sudo systemctl status node_exporter --no-pager",
      "curl -s http://localhost:9100/metrics | head -n 10"
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
