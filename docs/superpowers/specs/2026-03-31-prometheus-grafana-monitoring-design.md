---
name: Prometheus and Grafana Monitoring Integration
description: Add Prometheus and Grafana monitoring to existing Terraform infrastructure with custom AMI and auto-provisioned dashboards
type: feature
created: 2026-03-31
---

# Prometheus and Grafana Monitoring Design

## Overview

Extend the existing Terraform infrastructure to add comprehensive monitoring capabilities using Prometheus and Grafana. This design addresses the assignment requirement to deploy monitoring services and track CPU and memory utilization across all EC2 instances.

## Assignment Requirements

This design fulfills the following requirements:

1. **New Terraform file**: Create `monitoring.tf` for monitoring infrastructure
2. **Extra EC2 deployment**: 1 monitoring server in public subnet running both Prometheus and Grafana
3. **Updated AMI**: Include Prometheus node_exporter for metrics collection
4. **BONUS (25%)**: Auto-provisioned Grafana dashboard showing CPU and memory utilization for each EC2 instance

## Architecture

### Infrastructure Layout

```
VPC (10.0.0.0/16)
├── Public Subnets (2 AZs)
│   ├── us-east-1a: 10.0.1.0/24
│   │   └── Bastion Host (existing)
│   └── us-east-1b: 10.0.2.0/24
│       └── NEW: Monitoring Server
│           - Public IP for web access
│           - Prometheus UI: http://<public-ip>:9090
│           - Grafana UI: http://<public-ip>:3000
│
└── Private Subnets (2 AZs)
    ├── us-east-1a: 10.0.101.0/24
    │   └── 3 Private Instances (Docker + node_exporter)
    └── us-east-1b: 10.0.102.0/24
        └── 3 Private Instances (Docker + node_exporter)
```

### Component Architecture

#### 1. Updated AMI (Packer)

**Base:** Amazon Linux 2023

**Installed Software:**
- Docker (existing)
- docker-compose (existing)
- Prometheus node_exporter (NEW)

**Purpose:** Single AMI used by all instances:
- Bastion host (uses SSH key, Docker optional)
- 6 private instances (uses Docker + node_exporter)
- Monitoring server (uses Docker to run Prometheus/Grafana)

#### 2. Monitoring Server (New EC2)

**Deployment:**
- Location: Public subnet (us-east-1b)
- Instance type: t2.micro
- Public IP: Enabled
- AMI: Updated custom AMI

**Services (Docker Compose):**
- **Prometheus**: Metrics collection and storage
  - Port: 9090
  - Scrapes node_exporter from all 6 private instances every 15 seconds
  - Data retention: 15 days
  
- **Grafana**: Metrics visualization
  - Port: 3000
  - Auto-configured Prometheus datasource
  - Pre-provisioned dashboard for CPU/memory monitoring

#### 3. Monitored Instances (Existing)

**Changes:**
- Rebuilt with new AMI (adds node_exporter)
- node_exporter runs as systemd service
- Exposes metrics on port 9100
- Security group updated to allow :9100 from monitoring server

### Data Flow

```
[Private Instances 1-6]
    ↓ (expose metrics on :9100)
    ↓ node_exporter
    ↓
[Prometheus] ← scrapes every 15s
    ↓ (stores time-series data)
    ↓
[Grafana] ← queries Prometheus
    ↓
[User Browser] ← views dashboards at http://<ip>:3000
```

## Detailed Design

### 1. Packer AMI Updates

**File:** `packer/amazon-linux-docker.pkr.hcl`

**New Provisioners:**

```hcl
# Download and install node_exporter
provisioner "shell" {
  inline = [
    "echo 'Installing Prometheus node_exporter...'",
    "cd /tmp",
    "wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz",
    "tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz",
    "sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/",
    "sudo chmod +x /usr/local/bin/node_exporter",
    "rm -rf node_exporter-*"
  ]
}

# Create systemd service
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

    [Install]
    WantedBy=multi-user.target
  EOF
  destination = "/tmp/node_exporter.service"
}

# Enable and start service
provisioner "shell" {
  inline = [
    "sudo mv /tmp/node_exporter.service /etc/systemd/system/",
    "sudo systemctl daemon-reload",
    "sudo systemctl enable node_exporter",
    "sudo systemctl start node_exporter",
    "sleep 3",
    "curl -s http://localhost:9100/metrics | head -n 5"
  ]
}
```

**Verification Steps:**
- Verify node_exporter version
- Check systemd service status
- Curl metrics endpoint to confirm data
- Verify service enabled for boot

### 2. Terraform Monitoring Infrastructure

**New File:** `terraform/monitoring.tf`

#### Security Group

```hcl
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-monitoring-sg"
  description = "Security group for Prometheus and Grafana monitoring server"
  vpc_id      = module.vpc.vpc_id

  # SSH access from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip_final}/32"]
    description = "SSH access from my IP"
  }

  # Prometheus UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip_final}/32"]
    description = "Prometheus web UI"
  }

  # Grafana UI
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip_final}/32"]
    description = "Grafana web UI"
  }

  # Allow scraping metrics from private instances
  egress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
    description = "Scrape node_exporter metrics"
  }

  # General outbound for updates
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}
```

#### EC2 Instance

```hcl
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
    volume_size = 20  # Larger for Prometheus data
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
}
```

#### Configuration Deployment

**File Provisioners:**

1. **docker-compose.yml**
2. **prometheus.yml** (dynamically generated with instance IPs)
3. **grafana-datasource.yml** (Prometheus datasource config)
4. **grafana-dashboard.json** (CPU + Memory dashboard)
5. **grafana-dashboard-provider.yml** (auto-load dashboard)

**Remote-Exec Provisioner:**
```hcl
provisioner "remote-exec" {
  inline = [
    "cd /home/ec2-user/monitoring",
    "docker-compose up -d",
    "sleep 10",
    "docker-compose ps",
    "curl -s http://localhost:9090/-/healthy",
    "curl -s http://localhost:3000/api/health"
  ]
}
```

### 3. Monitoring Configurations

#### Docker Compose

**File:** `terraform/monitoring_configs/docker-compose.yml`

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
```

#### Prometheus Configuration

**File:** `terraform/monitoring_configs/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets:
          - '${instance_1_ip}:9100'
          - '${instance_2_ip}:9100'
          - '${instance_3_ip}:9100'
          - '${instance_4_ip}:9100'
          - '${instance_5_ip}:9100'
          - '${instance_6_ip}:9100'
        labels:
          env: 'dev'
          project: 'devops-spring26'
```

**Note:** Instance IPs will be dynamically templated using Terraform `templatefile()` function.

#### Grafana Datasource

**File:** `terraform/monitoring_configs/grafana/provisioning/datasources/prometheus.yml`

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

#### Grafana Dashboard Provider

**File:** `terraform/monitoring_configs/grafana/provisioning/dashboards/default.yml`

```yaml
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

#### Grafana Dashboard (BONUS Requirement)

**File:** `terraform/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json`

**Dashboard Structure:**

- **Title:** EC2 Instances Monitoring
- **Auto-refresh:** 30 seconds
- **6 Rows** (one per instance)

**Per Instance:**

1. **CPU Utilization Panel**
   - Type: Time series + Gauge
   - Query: `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",instance=~"10.0.101.x:9100"}[5m])) * 100)`
   - Unit: Percent (0-100)
   - Thresholds: Green (0-70), Yellow (70-85), Red (85-100)

2. **Memory Utilization Panel**
   - Type: Time series + Gauge
   - Query: `100 * (1 - (node_memory_MemAvailable_bytes{instance=~"10.0.101.x:9100"} / node_memory_MemTotal_bytes{instance=~"10.0.101.x:9100"}))`
   - Unit: Percent (0-100)
   - Thresholds: Green (0-70), Yellow (70-85), Red (85-100)

**Dashboard JSON:** Full dashboard will be generated with proper Grafana JSON schema including panels, targets, and layout.

### 4. Security Group Updates

**File:** `terraform/security_groups.tf`

**Update Private Security Group:**

```hcl
# Add to existing aws_security_group.private_sg
ingress {
  from_port       = 9100
  to_port         = 9100
  protocol        = "tcp"
  security_groups = [aws_security_group.monitoring_sg.id]
  description     = "Allow Prometheus to scrape node_exporter metrics"
}
```

### 5. Terraform Outputs

**File:** `terraform/outputs.tf`

**New Outputs:**

```hcl
output "monitoring_public_ip" {
  description = "Public IP of the monitoring server"
  value       = aws_instance.monitoring.public_ip
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "grafana_credentials" {
  description = "Grafana login credentials"
  value       = "Username: admin | Password: admin"
}
```

## Implementation Workflow

### Phase 1: Packer AMI Update

1. Update `packer/amazon-linux-docker.pkr.hcl` with node_exporter provisioners
2. Run `packer validate .`
3. Run `packer build .`
4. Save new AMI ID from build output
5. Update `terraform/terraform.tfvars` with new AMI ID

**Expected Duration:** 10-15 minutes (AMI build time)

### Phase 2: Monitoring Configurations

1. Create `terraform/monitoring_configs/` directory structure
2. Write `docker-compose.yml`
3. Write `prometheus.yml` template
4. Write Grafana provisioning configs:
   - `grafana/provisioning/datasources/prometheus.yml`
   - `grafana/provisioning/dashboards/default.yml`
   - `grafana/provisioning/dashboards/ec2-monitoring.json`

**Expected Duration:** Configuration creation

### Phase 3: Terraform Infrastructure

1. Create `terraform/monitoring.tf`
   - Monitoring security group
   - Monitoring EC2 instance
   - File provisioners (5 config files)
   - Remote-exec provisioner (start services)
2. Update `terraform/security_groups.tf` (private SG ingress rule)
3. Update `terraform/outputs.tf` (monitoring outputs)
4. Run `terraform fmt`
5. Run `terraform validate`

**Expected Duration:** Terraform code writing

### Phase 4: Deployment

1. Run `terraform plan` (review changes)
2. Run `terraform apply`
   - **Note:** All instances will be replaced due to new AMI
   - Total instances: 8 (1 bastion + 6 private + 1 monitoring)
3. Wait for deployment completion
4. Verify services:
   - SSH to monitoring instance
   - Check docker-compose status
   - Access Prometheus UI
   - Access Grafana UI
5. Verify metrics collection in Prometheus
6. Verify Grafana dashboard shows all 6 instances

**Expected Duration:** 5-10 minutes (Terraform apply)

### Phase 5: Documentation

1. Update `README.md`:
   - Add monitoring architecture section
   - Add Prometheus/Grafana access instructions
   - Add screenshots of monitoring UIs
   - Add dashboard usage guide
2. Take screenshots:
   - Prometheus targets page (showing all 6 instances UP)
   - Grafana dashboard with CPU/memory metrics
   - Individual instance metrics
3. Create verification steps

**Expected Duration:** Documentation and screenshot gathering

## Testing and Verification

### Packer AMI Verification

```bash
# After Packer build completes
aws ec2 describe-images --image-ids <ami-id>

# Verify tags include node_exporter
aws ec2 describe-images --image-ids <ami-id> --query 'Images[0].Tags'
```

### Infrastructure Verification

```bash
# After terraform apply
terraform output monitoring_public_ip
terraform output prometheus_url
terraform output grafana_url

# SSH to monitoring instance
ssh -i ~/.ssh/your-key ec2-user@<monitoring-ip>

# Check services running
docker-compose ps

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana health
curl http://localhost:3000/api/health
```

### Metrics Verification

**Prometheus Targets:**
- Navigate to http://<monitoring-ip>:9090/targets
- Verify all 6 instances show as "UP"
- Verify last scrape time is recent (<15s)

**Prometheus Queries:**
```promql
# Test CPU query
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Test memory query
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

**Grafana Dashboard:**
- Navigate to http://<monitoring-ip>:3000
- Login: admin / admin
- Dashboard should auto-load: "EC2 Instances Monitoring"
- Verify all 6 instances display metrics
- Verify real-time updates (30s refresh)

### Node Exporter Verification

```bash
# SSH to any private instance via bastion
ssh -J ec2-user@<bastion-ip> ec2-user@10.0.101.x

# Check node_exporter service
systemctl status node_exporter

# Check metrics locally
curl http://localhost:9100/metrics | grep node_cpu
curl http://localhost:9100/metrics | grep node_memory
```

## Security Considerations

### Network Security

1. **Monitoring Server:**
   - Ports 9090, 3000 only accessible from your IP
   - SSH only from your IP
   - Can reach private instances on :9100

2. **Private Instances:**
   - Port 9100 only accessible from monitoring security group
   - No internet access (no NAT gateway)
   - SSH only from bastion

3. **Security Groups:**
   - Use security group references (not CIDR blocks) for internal communication
   - Least-privilege access model

### Application Security

1. **Grafana:**
   - Default admin credentials (change in production)
   - No anonymous access
   - Datasource not editable by users

2. **Prometheus:**
   - Read-only access from Grafana
   - No authentication (secured by security group)

3. **node_exporter:**
   - Runs as ec2-user (not root)
   - Only exposes system metrics (no sensitive data)

## Cost Considerations

**Additional Costs:**

- **1 new t2.micro instance:** ~$0.0116/hour (~$8.50/month)
  - Free tier eligible (750 hours/month)
- **20GB EBS volume:** ~$2/month
- **Data transfer:** Minimal (internal VPC traffic is free)

**Total Additional Cost:** ~$0-10/month depending on free tier eligibility

**Cost Optimization:**
- Use t2.micro (free tier eligible)
- 15-day retention (vs. default 15 years)
- Stop/destroy when not needed

## Troubleshooting

### Common Issues

**Packer build fails:**
- Verify node_exporter download URL is correct
- Check systemd service syntax
- Verify service starts without errors

**Prometheus not scraping:**
- Check security group allows :9100 from monitoring SG
- Verify node_exporter is running on private instances
- Check Prometheus targets page for error messages
- Verify private instance IPs in prometheus.yml are correct

**Grafana dashboard not loading:**
- Check provisioning directory mounted correctly
- Verify JSON syntax in dashboard file
- Check Grafana logs: `docker-compose logs grafana`
- Verify datasource configured correctly

**Docker compose fails to start:**
- Check SSH connection during file provisioner
- Verify docker service is running
- Check disk space on monitoring instance
- Review remote-exec output for errors

## README Documentation Sections

The README should include:

### 1. Monitoring Architecture

- Architecture diagram showing monitoring flow
- Component descriptions
- Network security diagram

### 2. Accessing Monitoring Services

```bash
# Get monitoring URLs
terraform output prometheus_url
terraform output grafana_url

# Access Grafana
# Username: admin
# Password: admin
# Dashboard: EC2 Instances Monitoring
```

### 3. Prometheus Usage

- How to access Prometheus UI
- Sample queries for CPU and memory
- Targets verification steps

### 4. Grafana Dashboard

- How to access the dashboard
- Description of panels
- How to customize time ranges
- Screenshot of dashboard

### 5. Verification Steps

- How to verify all instances are being monitored
- How to check metrics are flowing
- Troubleshooting common issues

### 6. Screenshots Required

1. Prometheus targets page (all instances UP)
2. Grafana login page
3. Grafana dashboard full view
4. Individual instance CPU metrics
5. Individual instance memory metrics
6. Prometheus metrics query result

## Success Criteria

This design is successful when:

1. ✅ New AMI built with Docker + node_exporter
2. ✅ All 8 instances (bastion + 6 private + monitoring) running with new AMI
3. ✅ Monitoring EC2 instance deployed in public subnet
4. ✅ Prometheus collecting metrics from all 6 private instances
5. ✅ Grafana accessible via web browser
6. ✅ Dashboard auto-provisioned and showing CPU + memory for all 6 instances
7. ✅ Real-time metrics updating in dashboard
8. ✅ README updated with monitoring documentation
9. ✅ Screenshots demonstrating working monitoring system
10. ✅ All verification steps passing

## Non-Goals

This design explicitly does NOT include:

- AlertManager or alerting rules
- Long-term metric storage (S3, Thanos)
- High availability or redundancy
- HTTPS/TLS encryption
- Production-grade authentication
- Custom metric exporters
- Log aggregation
- Distributed tracing

These are intentionally excluded to keep the implementation focused on the assignment requirements.

## Dependencies

**External:**
- Prometheus official Docker images
- Grafana official Docker images
- Prometheus node_exporter GitHub releases

**Internal:**
- Existing VPC and subnet configuration
- Existing security group structure
- Updated AMI from Packer build
- Private instance IPs (dynamic from Terraform)

## Rollback Plan

If deployment fails or issues arise:

1. **Terraform rollback:**
   ```bash
   # Destroy only monitoring resources
   terraform destroy -target=aws_instance.monitoring
   terraform destroy -target=aws_security_group.monitoring_sg
   ```

2. **Revert to old AMI:**
   - Update terraform.tfvars with original AMI ID
   - Run terraform apply
   - All instances revert to previous AMI

3. **Full rollback:**
   ```bash
   terraform destroy  # Destroy everything
   # Revert code changes
   git checkout main
   terraform apply  # Redeploy original infrastructure
   ```

**Low Risk:** Changes are additive; existing infrastructure remains functional even if monitoring fails.
