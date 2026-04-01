# Security Group for Monitoring Server
resource "aws_security_group" "monitoring_sg" {
  name_prefix = "${var.project_name}-monitoring-"
  description = "Security group for monitoring server - Prometheus and Grafana"
  vpc_id      = module.vpc.vpc_id

  # SSH from my IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip_final}/32"]
    description = "SSH from my IP"
  }

  # Prometheus web UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip_final}/32"]
    description = "Prometheus web UI"
  }

  # Grafana web UI
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip_final}/32"]
    description = "Grafana web UI"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "${var.project_name}-monitoring-sg"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Monitoring Server in Public Subnet
resource "aws_instance" "monitoring" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.project_name}-monitoring"
    Project = var.project_name
    Type    = "monitoring"
  }

  # Create directories for monitoring stack
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/monitoring/grafana/provisioning/datasources",
      "mkdir -p ~/monitoring/grafana/provisioning/dashboards"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
    }
  }

  # Upload docker-compose.yml
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/docker-compose.yml"
    destination = "~/monitoring/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
    }
  }

  # Upload Prometheus config (with private IPs templated)
  provisioner "file" {
    content = templatefile("${path.module}/monitoring_configs/prometheus.yml.tpl", {
      private_ips = aws_instance.private[*].private_ip
    })
    destination = "~/monitoring/prometheus.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
    }
  }

  # Upload Grafana datasource config
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/datasources/prometheus.yml"
    destination = "~/monitoring/grafana/provisioning/datasources/prometheus.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
    }
  }

  # Upload Grafana dashboard provider config
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/dashboards/default.yml"
    destination = "~/monitoring/grafana/provisioning/dashboards/default.yml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
    }
  }

  # Upload Grafana dashboard JSON
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json"
    destination = "~/monitoring/grafana/provisioning/dashboards/ec2-monitoring.json"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
    }
  }

  # Start monitoring stack
  provisioner "remote-exec" {
    inline = [
      "cd ~/monitoring",
      "docker-compose up -d"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
    }
  }
}
