# Security Group for Monitoring Server
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-monitoring-sg"
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

  # Outbound to scrape metrics from private instances
  egress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
    description = "Scrape node_exporter metrics"
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
  subnet_id                   = module.vpc.public_subnets[1]
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  # Wait for private instances to be ready
  depends_on = [aws_instance.private]

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

  connection {
    type  = "ssh"
    user  = "ec2-user"
    agent = true
    host  = self.public_ip
  }

  # Create directories for monitoring stack
  provisioner "remote-exec" {
    inline = [
      "echo 'Creating monitoring directories...'",
      "mkdir -p /home/ec2-user/monitoring/grafana/provisioning/datasources",
      "mkdir -p /home/ec2-user/monitoring/grafana/provisioning/dashboards",
      "ls -la /home/ec2-user/",
      "echo 'Directories created successfully'"
    ]
  }

  # Upload docker-compose.yml
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/docker-compose.yml"
    destination = "/home/ec2-user/monitoring/docker-compose.yml"
  }

  # Upload Prometheus config (with private IPs templated)
  provisioner "file" {
    content = templatefile("${path.module}/monitoring_configs/prometheus.yml.tpl", {
      private_ips = aws_instance.private[*].private_ip
    })
    destination = "/home/ec2-user/monitoring/prometheus.yml"
  }

  # Upload Grafana datasource config
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/datasources/prometheus.yml"
    destination = "/home/ec2-user/monitoring/grafana/provisioning/datasources/prometheus.yml"
  }

  # Upload Grafana dashboard provider config
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/dashboards/default.yml"
    destination = "/home/ec2-user/monitoring/grafana/provisioning/dashboards/default.yml"
  }

  # Upload Grafana dashboard JSON
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json"
    destination = "/home/ec2-user/monitoring/grafana/provisioning/dashboards/ec2-monitoring.json"
  }

  # Start monitoring stack
  provisioner "remote-exec" {
    inline = [
      "echo 'Starting monitoring stack...'",
      "cd /home/ec2-user/monitoring",
      "docker-compose up -d",
      "echo 'Waiting for services to start...'",
      "sleep 15",
      "docker-compose ps",
      "echo 'Checking Prometheus health...'",
      "curl -s http://localhost:9090/-/healthy || echo 'Prometheus not ready yet'",
      "echo 'Checking Grafana health...'",
      "curl -s http://localhost:3000/api/health || echo 'Grafana not ready yet'",
      "echo 'Monitoring stack deployment complete!'"
    ]
  }
}
