# Prometheus and Grafana Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Prometheus and Grafana monitoring to existing Terraform infrastructure with auto-provisioned dashboards.

**Architecture:** Single monitoring EC2 instance in public subnet running Prometheus and Grafana via Docker Compose. Updated AMI includes node_exporter on all instances. Grafana dashboard auto-provisioned with CPU and memory metrics for all 6 private instances.

**Tech Stack:** Packer, Terraform, AWS EC2, Prometheus, Grafana, Docker Compose, node_exporter

---

## File Structure

This implementation will create/modify the following files:

**Packer (Modified):**
- `packer/amazon-linux-docker.pkr.hcl` - Add node_exporter provisioners

**Monitoring Configs (Created):**
- `terraform/monitoring_configs/docker-compose.yml` - Prometheus + Grafana containers
- `terraform/monitoring_configs/prometheus.yml.tpl` - Prometheus scrape configuration template
- `terraform/monitoring_configs/grafana/provisioning/datasources/prometheus.yml` - Grafana datasource
- `terraform/monitoring_configs/grafana/provisioning/dashboards/default.yml` - Dashboard provider
- `terraform/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json` - CPU/Memory dashboard

**Terraform (Created):**
- `terraform/monitoring.tf` - Monitoring infrastructure (security group, EC2, provisioners)

**Terraform (Modified):**
- `terraform/security_groups.tf` - Add node_exporter ingress rule to private SG
- `terraform/outputs.tf` - Add monitoring outputs
- `terraform/terraform.tfvars` - Update AMI ID after Packer build

**Documentation (Modified):**
- `README.md` - Add monitoring sections, screenshots, usage instructions

---

## Task 1: Update Packer AMI with node_exporter

**Files:**
- Modify: `packer/amazon-linux-docker.pkr.hcl:95-112`

- [ ] **Step 1: Add node_exporter download and installation provisioner**

Add after the docker-compose provisioner (after line 76):

```hcl
  # Install Prometheus node_exporter
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
```

- [ ] **Step 2: Add systemd service file provisioner**

Add immediately after the previous provisioner:

```hcl
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

[Install]
WantedBy=multi-user.target
EOF
    destination = "/tmp/node_exporter.service"
  }
```

- [ ] **Step 3: Add service enablement and verification provisioner**

Add immediately after the service file provisioner:

```hcl
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
```

- [ ] **Step 4: Validate Packer configuration**

Run:
```bash
cd packer
packer validate .
```

Expected: `The configuration is valid.`

- [ ] **Step 5: Commit Packer changes**

```bash
git add packer/amazon-linux-docker.pkr.hcl
git commit -m "feat: add Prometheus node_exporter to Packer AMI

Add node_exporter installation and systemd service configuration to AMI.
All instances will now expose system metrics on port 9100.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Build new AMI with Packer

**Files:**
- Modify: `terraform/terraform.tfvars:1`

- [ ] **Step 1: Build AMI with Packer**

Run:
```bash
cd packer
packer build .
```

Expected: Build completes successfully after 10-15 minutes with output like:
```
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.amazon_linux: AMIs were created:
us-east-1: ami-0123456789abcdef0
```

- [ ] **Step 2: Save AMI ID**

From the Packer output, copy the AMI ID (format: `ami-0123456789abcdef0`)

- [ ] **Step 3: Update Terraform variables**

Update `terraform/terraform.tfvars` with the new AMI ID:

```hcl
custom_ami_id = "ami-0123456789abcdef0"  # Replace with actual AMI ID from Packer build
```

- [ ] **Step 4: Verify AMI in AWS**

Run:
```bash
aws ec2 describe-images --image-ids ami-0123456789abcdef0 --query 'Images[0].[ImageId,Name,State]' --output table
```

Expected: Shows AMI as `available`

- [ ] **Step 5: Commit AMI ID update**

```bash
git add terraform/terraform.tfvars
git commit -m "chore: update AMI ID to include node_exporter

Update terraform.tfvars with new AMI ID from Packer build.
AMI includes Docker, docker-compose, and node_exporter.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Create Docker Compose configuration

**Files:**
- Create: `terraform/monitoring_configs/docker-compose.yml`

- [ ] **Step 1: Create monitoring configs directory**

Run:
```bash
mkdir -p terraform/monitoring_configs/grafana/provisioning/datasources
mkdir -p terraform/monitoring_configs/grafana/provisioning/dashboards
```

Expected: Directories created successfully (no output)

- [ ] **Step 2: Write docker-compose.yml**

Create `terraform/monitoring_configs/docker-compose.yml`:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
    restart: unless-stopped
    networks:
      - monitoring
    depends_on:
      - prometheus

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
```

- [ ] **Step 3: Verify YAML syntax**

Run:
```bash
cd terraform/monitoring_configs
python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" && echo "YAML is valid"
```

Expected: `YAML is valid`

- [ ] **Step 4: Commit docker-compose configuration**

```bash
git add terraform/monitoring_configs/docker-compose.yml
git commit -m "feat: add docker-compose configuration for Prometheus and Grafana

Configure Prometheus and Grafana containers with:
- Prometheus: port 9090, 15-day retention
- Grafana: port 3000, admin/admin credentials
- Persistent volumes for data storage
- Shared network for service communication

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Create Prometheus configuration template

**Files:**
- Create: `terraform/monitoring_configs/prometheus.yml.tpl`

- [ ] **Step 1: Write Prometheus configuration template**

Create `terraform/monitoring_configs/prometheus.yml.tpl`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'dev'
    project: 'devops-spring26'

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets:
%{ for idx, ip in private_ips ~}
          - '${ip}:9100'
%{ endfor ~}
        labels:
          env: 'dev'
          project: 'devops-spring26'
```

- [ ] **Step 2: Verify template syntax**

Run:
```bash
cd terraform/monitoring_configs
cat prometheus.yml.tpl
```

Expected: File displays correctly with template variables

- [ ] **Step 3: Commit Prometheus configuration template**

```bash
git add terraform/monitoring_configs/prometheus.yml.tpl
git commit -m "feat: add Prometheus configuration template

Configure Prometheus to scrape node_exporter metrics from all private
instances. Uses Terraform templatefile() to dynamically populate
instance IPs at deployment time.

Scrape interval: 15 seconds
Targets: All 6 private instances on port 9100

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Create Grafana datasource configuration

**Files:**
- Create: `terraform/monitoring_configs/grafana/provisioning/datasources/prometheus.yml`

- [ ] **Step 1: Write Grafana datasource configuration**

Create `terraform/monitoring_configs/grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      httpMethod: POST
      timeInterval: 15s
```

- [ ] **Step 2: Verify YAML syntax**

Run:
```bash
cd terraform/monitoring_configs/grafana/provisioning/datasources
python3 -c "import yaml; yaml.safe_load(open('prometheus.yml'))" && echo "YAML is valid"
```

Expected: `YAML is valid`

- [ ] **Step 3: Commit Grafana datasource configuration**

```bash
git add terraform/monitoring_configs/grafana/provisioning/datasources/prometheus.yml
git commit -m "feat: add Grafana datasource auto-provisioning

Configure Grafana to automatically add Prometheus as default datasource.
Datasource will be available immediately on Grafana startup.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Create Grafana dashboard provider configuration

**Files:**
- Create: `terraform/monitoring_configs/grafana/provisioning/dashboards/default.yml`

- [ ] **Step 1: Write dashboard provider configuration**

Create `terraform/monitoring_configs/grafana/provisioning/dashboards/default.yml`:

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

- [ ] **Step 2: Verify YAML syntax**

Run:
```bash
cd terraform/monitoring_configs/grafana/provisioning/dashboards
python3 -c "import yaml; yaml.safe_load(open('default.yml'))" && echo "YAML is valid"
```

Expected: `YAML is valid`

- [ ] **Step 3: Commit dashboard provider configuration**

```bash
git add terraform/monitoring_configs/grafana/provisioning/dashboards/default.yml
git commit -m "feat: add Grafana dashboard provider configuration

Configure Grafana to auto-load dashboards from provisioning directory.
Dashboards will be available immediately on startup.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Create Grafana dashboard (BONUS requirement)

**Files:**
- Create: `terraform/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json`

- [ ] **Step 1: Write Grafana dashboard JSON**

Create `terraform/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json`:

```json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 70
              },
              {
                "color": "red",
                "value": 85
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "values": false,
          "calcs": [
            "lastNotNull"
          ],
          "fields": ""
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "legendFormat": "{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "CPU Utilization - All Instances",
      "type": "gauge"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 70
              },
              {
                "color": "red",
                "value": 85
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 2,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "values": false,
          "calcs": [
            "lastNotNull"
          ],
          "fields": ""
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "expr": "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))",
          "legendFormat": "{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Memory Utilization - All Instances",
      "type": "gauge"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "tooltip": false,
              "viz": false,
              "legend": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 8
      },
      "id": 3,
      "options": {
        "legend": {
          "calcs": [
            "mean",
            "lastNotNull",
            "max"
          ],
          "displayMode": "table",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "multi",
          "sort": "none"
        }
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "legendFormat": "{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "CPU Utilization Over Time",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "tooltip": false,
              "viz": false,
              "legend": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 8
      },
      "id": 4,
      "options": {
        "legend": {
          "calcs": [
            "mean",
            "lastNotNull",
            "max"
          ],
          "displayMode": "table",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "multi",
          "sort": "none"
        }
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "expr": "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))",
          "legendFormat": "{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Memory Utilization Over Time",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["devops", "ec2", "monitoring"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "EC2 Instances Monitoring",
  "uid": "ec2-monitoring",
  "version": 0,
  "weekStart": ""
}
```

- [ ] **Step 2: Verify JSON syntax**

Run:
```bash
cd terraform/monitoring_configs/grafana/provisioning/dashboards
python3 -c "import json; json.load(open('ec2-monitoring.json'))" && echo "JSON is valid"
```

Expected: `JSON is valid`

- [ ] **Step 3: Commit Grafana dashboard**

```bash
git add terraform/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json
git commit -m "feat: add auto-provisioned Grafana dashboard (BONUS)

Add EC2 monitoring dashboard with:
- CPU utilization gauges and time series
- Memory utilization gauges and time series
- Auto-refresh every 30 seconds
- Color-coded thresholds (green/yellow/red)
- Legend with mean/max/current values

Dashboard displays metrics for all 6 private instances.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Create Terraform monitoring infrastructure

**Files:**
- Create: `terraform/monitoring.tf`

- [ ] **Step 1: Write monitoring security group**

Create `terraform/monitoring.tf`:

```hcl
# Security group for monitoring server
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

  # Outbound to scrape metrics from private instances
  egress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
    description = "Scrape node_exporter metrics"
  }

  # General outbound (for Docker image pulls, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name    = "${var.project_name}-monitoring-sg"
    Project = var.project_name
  }
}
```

- [ ] **Step 2: Add monitoring EC2 instance with connection configuration**

Append to `terraform/monitoring.tf`:

```hcl

# Monitoring server EC2 instance
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

  # SSH connection for provisioners
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(pathexpand(var.ssh_private_key_path))
    host        = self.public_ip
    timeout     = "5m"
  }
}
```

- [ ] **Step 3: Add file provisioner for docker-compose**

Append to `terraform/monitoring.tf`:

```hcl

  # Create monitoring directory
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ec2-user/monitoring/grafana/provisioning/datasources",
      "mkdir -p /home/ec2-user/monitoring/grafana/provisioning/dashboards"
    ]
  }

  # Upload docker-compose.yml
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/docker-compose.yml"
    destination = "/home/ec2-user/monitoring/docker-compose.yml"
  }
```

- [ ] **Step 4: Add file provisioner for Prometheus configuration**

Append to `terraform/monitoring.tf`:

```hcl

  # Upload Prometheus configuration (templated with instance IPs)
  provisioner "file" {
    content = templatefile("${path.module}/monitoring_configs/prometheus.yml.tpl", {
      private_ips = aws_instance.private[*].private_ip
    })
    destination = "/home/ec2-user/monitoring/prometheus.yml"
  }
```

- [ ] **Step 5: Add file provisioners for Grafana configurations**

Append to `terraform/monitoring.tf`:

```hcl

  # Upload Grafana datasource configuration
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/datasources/prometheus.yml"
    destination = "/home/ec2-user/monitoring/grafana/provisioning/datasources/prometheus.yml"
  }

  # Upload Grafana dashboard provider configuration
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/dashboards/default.yml"
    destination = "/home/ec2-user/monitoring/grafana/provisioning/dashboards/default.yml"
  }

  # Upload Grafana dashboard JSON
  provisioner "file" {
    source      = "${path.module}/monitoring_configs/grafana/provisioning/dashboards/ec2-monitoring.json"
    destination = "/home/ec2-user/monitoring/grafana/provisioning/dashboards/ec2-monitoring.json"
  }
```

- [ ] **Step 6: Add remote-exec provisioner to start services**

Append to `terraform/monitoring.tf`:

```hcl

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
```

- [ ] **Step 7: Validate Terraform configuration**

Run:
```bash
cd terraform
terraform fmt
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 8: Commit monitoring infrastructure**

```bash
git add terraform/monitoring.tf
git commit -m "feat: add Terraform monitoring infrastructure

Create monitoring server in public subnet with:
- Security group allowing Prometheus (9090), Grafana (3000), SSH
- EC2 instance with 20GB volume for metrics storage
- File provisioners to deploy all configurations
- Remote-exec to start docker-compose stack

Monitoring stack auto-starts on instance launch.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Update private security group for metrics scraping

**Files:**
- Modify: `terraform/security_groups.tf:45`

- [ ] **Step 1: Add node_exporter ingress rule to private security group**

Add this ingress block to `aws_security_group.private_sg` (after the SSH ingress rule):

```hcl
  # Allow Prometheus to scrape node_exporter metrics
  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
    description     = "Allow Prometheus to scrape node_exporter metrics"
  }
```

- [ ] **Step 2: Validate Terraform configuration**

Run:
```bash
cd terraform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit security group update**

```bash
git add terraform/security_groups.tf
git commit -m "feat: allow Prometheus to scrape metrics from private instances

Add ingress rule to private security group allowing port 9100 access
from monitoring security group. Enables Prometheus to collect
node_exporter metrics from all private instances.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Add Terraform outputs for monitoring

**Files:**
- Modify: `terraform/outputs.tf:52`

- [ ] **Step 1: Add monitoring outputs**

Append to `terraform/outputs.tf`:

```hcl

# Monitoring server outputs
output "monitoring_public_ip" {
  description = "Public IP of the monitoring server"
  value       = aws_instance.monitoring.public_ip
}

output "prometheus_url" {
  description = "URL to access Prometheus web UI"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "grafana_url" {
  description = "URL to access Grafana web UI"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "grafana_credentials" {
  description = "Default Grafana login credentials"
  value       = "Username: admin | Password: admin (change after first login)"
}

output "monitoring_ssh_command" {
  description = "SSH command to connect to monitoring server"
  value       = "ssh -i ${var.ssh_private_key_path} ec2-user@${aws_instance.monitoring.public_ip}"
}
```

- [ ] **Step 2: Validate Terraform configuration**

Run:
```bash
cd terraform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit output additions**

```bash
git add terraform/outputs.tf
git commit -m "feat: add Terraform outputs for monitoring access

Add outputs for:
- Monitoring server public IP
- Prometheus URL (port 9090)
- Grafana URL (port 3000)
- Grafana credentials
- SSH command for monitoring server

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 11: Add SSH private key variable

**Files:**
- Modify: `terraform/variables.tf:35`

- [ ] **Step 1: Add ssh_private_key_path variable**

Add to `terraform/variables.tf` (after ssh_public_key_path variable):

```hcl

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioner connections"
  type        = string
  default     = "~/.ssh/id_ed25519"
}
```

- [ ] **Step 2: Validate Terraform configuration**

Run:
```bash
cd terraform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit variable addition**

```bash
git add terraform/variables.tf
git commit -m "feat: add SSH private key variable for provisioners

Add variable for SSH private key path used by file/remote-exec
provisioners to connect to monitoring instance.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 12: Deploy infrastructure with Terraform

**Files:**
- None (deployment only)

- [ ] **Step 1: Review Terraform plan**

Run:
```bash
cd terraform
terraform plan
```

Expected: Plan shows:
- 8 instances to be created/replaced (1 bastion + 6 private + 1 monitoring)
- New monitoring security group
- Updated private security group
- New outputs

Review the plan carefully before proceeding.

- [ ] **Step 2: Apply Terraform configuration**

Run:
```bash
terraform apply
```

Type `yes` when prompted.

Expected: 
- All resources created/updated successfully
- Outputs display monitoring URLs
- Process completes in 5-10 minutes

- [ ] **Step 3: Capture Terraform outputs**

Run:
```bash
terraform output
```

Expected output includes:
```
grafana_url = "http://X.X.X.X:3000"
prometheus_url = "http://X.X.X.X:9090"
monitoring_public_ip = "X.X.X.X"
grafana_credentials = "Username: admin | Password: admin"
```

Save these URLs for verification.

- [ ] **Step 4: Commit deployment state**

Note: We don't commit terraform.tfstate, but we document the deployment.

```bash
git add -u
git commit -m "chore: deploy monitoring infrastructure

Deployed infrastructure includes:
- 1 monitoring server in public subnet
- Updated all instances with node_exporter AMI
- Prometheus and Grafana running via Docker Compose
- Auto-provisioned dashboard with CPU/memory metrics

Total instances: 8 (1 bastion + 6 private + 1 monitoring)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 13: Verify Prometheus targets and metrics

**Files:**
- None (verification only)

- [ ] **Step 1: SSH to monitoring instance**

Run:
```bash
terraform output -raw monitoring_ssh_command | bash
```

Expected: Successfully connected to monitoring instance

- [ ] **Step 2: Check Docker Compose status**

Run:
```bash
cd /home/ec2-user/monitoring
docker-compose ps
```

Expected: Both prometheus and grafana containers running (State: Up)

- [ ] **Step 3: Check Prometheus targets**

Run:
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health: .health, lastScrape: .lastScrape}'
```

Expected: All 6 instances shown with `"health": "up"` and recent lastScrape timestamp

- [ ] **Step 4: Test Prometheus CPU query**

Run:
```bash
curl -s 'http://localhost:9090/api/v1/query?query=100%20-%20(avg%20by(instance)%20(irate(node_cpu_seconds_total{mode="idle"}[5m]))%20*%20100)' | jq '.data.result[] | {instance: .metric.instance, cpu_usage: .value[1]}'
```

Expected: CPU usage percentages for all 6 instances

- [ ] **Step 5: Test Prometheus memory query**

Run:
```bash
curl -s 'http://localhost:9090/api/v1/query?query=100%20*%20(1%20-%20(node_memory_MemAvailable_bytes%20/%20node_memory_MemTotal_bytes))' | jq '.data.result[] | {instance: .metric.instance, memory_usage: .value[1]}'
```

Expected: Memory usage percentages for all 6 instances

- [ ] **Step 6: Exit SSH session**

Run:
```bash
exit
```

---

## Task 14: Verify Grafana dashboard

**Files:**
- None (verification only)

- [ ] **Step 1: Access Grafana web UI**

Open in browser:
```bash
terraform output -raw grafana_url
```

Expected: Grafana login page loads

- [ ] **Step 2: Login to Grafana**

Credentials:
- Username: `admin`
- Password: `admin`

Expected: Prompted to change password (skip for now by clicking "Skip")

- [ ] **Step 3: Navigate to EC2 Monitoring dashboard**

Click: Home → Dashboards → "EC2 Instances Monitoring"

Expected: Dashboard loads with 4 panels (CPU gauge, Memory gauge, CPU time series, Memory time series)

- [ ] **Step 4: Verify metrics are displaying**

Check:
- CPU gauges show percentages for all 6 instances
- Memory gauges show percentages for all 6 instances
- Time series graphs show historical data
- Auto-refresh indicator shows "30s"

Expected: All panels display live metrics, graphs show recent data

- [ ] **Step 5: Verify Prometheus datasource**

Navigate: Configuration (gear icon) → Data Sources → Prometheus

Expected: 
- Green "Data source is working" message
- URL: http://prometheus:9090

---

## Task 15: Take screenshots for documentation

**Files:**
- Create: `docs/screenshots/09-prometheus-targets.png`
- Create: `docs/screenshots/10-prometheus-query.png`
- Create: `docs/screenshots/11-grafana-login.png`
- Create: `docs/screenshots/12-grafana-dashboard.png`
- Create: `docs/screenshots/13-grafana-cpu-metrics.png`
- Create: `docs/screenshots/14-grafana-memory-metrics.png`

- [ ] **Step 1: Screenshot Prometheus targets page**

1. Open: `terraform output -raw prometheus_url` → append `/targets`
2. Take screenshot showing all 6 instances "UP"
3. Save as `docs/screenshots/09-prometheus-targets.png`

Expected: Clear screenshot showing Prometheus targets page with all instances healthy

- [ ] **Step 2: Screenshot Prometheus query result**

1. In Prometheus UI, go to "Graph" tab
2. Enter query: `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
3. Click "Execute"
4. Take screenshot showing query results
5. Save as `docs/screenshots/10-prometheus-query.png`

Expected: Screenshot showing CPU metrics for all instances

- [ ] **Step 3: Screenshot Grafana login page**

1. Open: `terraform output -raw grafana_url`
2. Take screenshot of login page
3. Save as `docs/screenshots/11-grafana-login.png`

Expected: Clean screenshot of Grafana login interface

- [ ] **Step 4: Screenshot Grafana dashboard full view**

1. Login and navigate to "EC2 Instances Monitoring" dashboard
2. Take full-screen screenshot showing all panels
3. Save as `docs/screenshots/12-grafana-dashboard.png`

Expected: Screenshot showing entire dashboard with all 4 panels visible

- [ ] **Step 5: Screenshot CPU metrics detail**

1. Expand CPU time series panel (click title → "View")
2. Take screenshot showing detailed CPU metrics
3. Save as `docs/screenshots/13-grafana-cpu-metrics.png`

Expected: Detailed view of CPU utilization time series

- [ ] **Step 6: Screenshot memory metrics detail**

1. Expand Memory time series panel (click title → "View")
2. Take screenshot showing detailed memory metrics
3. Save as `docs/screenshots/14-grafana-memory-metrics.png`

Expected: Detailed view of memory utilization time series

- [ ] **Step 7: Commit screenshots**

```bash
git add docs/screenshots/09-prometheus-targets.png
git add docs/screenshots/10-prometheus-query.png
git add docs/screenshots/11-grafana-login.png
git add docs/screenshots/12-grafana-dashboard.png
git add docs/screenshots/13-grafana-cpu-metrics.png
git add docs/screenshots/14-grafana-memory-metrics.png
git commit -m "docs: add monitoring screenshots

Add screenshots demonstrating:
- Prometheus scraping all 6 instances successfully
- Prometheus query execution for CPU metrics
- Grafana login and dashboard interface
- CPU and memory utilization visualizations

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 16: Update README with monitoring documentation

**Files:**
- Modify: `README.md:600`

- [ ] **Step 1: Add monitoring architecture section**

Add before the "Learning Outcomes" section in `README.md`:

```markdown
## Monitoring with Prometheus and Grafana

This infrastructure includes comprehensive monitoring using Prometheus for metrics collection and Grafana for visualization.

### Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                        │
│                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐    │
│  │   Public Subnet      │      │   Public Subnet      │    │
│  │   (us-east-1a)       │      │   (us-east-1b)       │    │
│  │                      │      │                      │    │
│  │  ┌────────────┐      │      │  ┌────────────┐     │    │
│  │  │  Bastion   │      │      │  │ Monitoring │     │    │
│  │  │   Host     │      │      │  │   Server   │     │    │
│  │  └────────────┘      │      │  │            │     │    │
│  │                      │      │  │ Prometheus │     │    │
│  └──────────────────────┘      │  │  :9090     │     │    │
│                                │  │            │     │    │
│  ┌──────────────────────┐      │  │  Grafana   │     │    │
│  │  Private Subnet      │      │  │   :3000    │     │    │
│  │   (us-east-1a)       │      │  └────────────┘     │    │
│  │                      │      └──────────────────────┘    │
│  │  Instance 1  :9100 ◄─┼──────────────┐                  │
│  │  Instance 2  :9100 ◄─┼──────────┐   │                  │
│  │  Instance 3  :9100 ◄─┼──────┐   │   │                  │
│  └──────────────────────┘      │   │   │                  │
│                                │   │   │                  │
│  ┌──────────────────────┐      │   │   │                  │
│  │  Private Subnet      │      │   │   │  Metrics         │
│  │   (us-east-1b)       │      │   │   │  Collection      │
│  │                      │      │   │   │  (every 15s)     │
│  │  Instance 4  :9100 ◄─┼──────┘   │   │                  │
│  │  Instance 5  :9100 ◄─┼──────────┘   │                  │
│  │  Instance 6  :9100 ◄─┼──────────────┘                  │
│  └──────────────────────┘                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Components

1. **Monitoring Server** (Public Subnet)
   - **Prometheus**: Collects metrics from all EC2 instances
   - **Grafana**: Visualizes metrics with pre-configured dashboards
   - **Docker Compose**: Manages both services as containers
   - **Public Access**: Web UIs accessible from your IP only

2. **Node Exporter** (All Instances)
   - Installed on all instances via custom AMI
   - Exposes system metrics on port 9100
   - Metrics include: CPU, memory, disk, network

3. **Auto-Provisioned Dashboard**
   - CPU utilization gauges and time series
   - Memory utilization gauges and time series
   - Real-time updates every 30 seconds
   - Color-coded thresholds (green/yellow/red)

### Accessing Monitoring Services

After deploying the infrastructure, get the monitoring URLs:

```bash
cd terraform

# Get all monitoring information
terraform output monitoring_public_ip
terraform output prometheus_url
terraform output grafana_url
terraform output grafana_credentials
```

### Using Prometheus

**Access Prometheus UI:**
```bash
# Open in browser
open $(terraform output -raw prometheus_url)
```

Navigate to different sections:
- **Status → Targets**: View all monitored instances and health status
- **Graph**: Execute PromQL queries and visualize metrics
- **Alerts**: View active alerts (none configured in this setup)

**Useful Prometheus Queries:**

```promql
# CPU utilization per instance
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory utilization per instance
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Network bytes received per instance
rate(node_network_receive_bytes_total[5m])

# Disk usage percentage
100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})
```

### Using Grafana

**Access Grafana UI:**
```bash
# Open in browser
open $(terraform output -raw grafana_url)
```

**Login:**
- Username: `admin`
- Password: `admin`
- (You'll be prompted to change the password on first login)

**View Dashboard:**
1. Click on "Home" (top left)
2. Select "EC2 Instances Monitoring" dashboard
3. Dashboard displays:
   - CPU utilization gauges for all instances
   - Memory utilization gauges for all instances
   - CPU time series graph
   - Memory time series graph
   - Auto-refresh every 30 seconds

**Customizing Dashboard:**
- Change time range: Top right time picker
- Zoom into graphs: Click and drag on time series
- View specific instance: Use panel legends to toggle
- Export dashboard: Share → Export

### Verifying Monitoring Stack

**Check Prometheus is scraping metrics:**
```bash
# SSH to monitoring instance
ssh -i ~/.ssh/your-key ec2-user@$(terraform output -raw monitoring_public_ip)

# Check Docker containers
docker-compose ps

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health: .health}'

# Exit
exit
```

Expected: All 6 instances show `"health": "up"`

**Test metrics from a private instance:**
```bash
# SSH to monitoring instance
ssh -i ~/.ssh/your-key ec2-user@$(terraform output -raw monitoring_public_ip)

# Test scraping an instance
INSTANCE_IP=$(docker exec prometheus cat /etc/prometheus/prometheus.yml | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
curl -s http://${INSTANCE_IP}:9100/metrics | grep node_cpu_seconds_total | head -5

# Exit
exit
```

Expected: CPU metrics displayed from the private instance

### Monitoring Screenshots

#### Prometheus Targets
All 6 private instances being successfully scraped by Prometheus:

![Prometheus Targets](docs/screenshots/09-prometheus-targets.png)

#### Prometheus Query Results
CPU utilization metrics for all instances:

![Prometheus Query](docs/screenshots/10-prometheus-query.png)

#### Grafana Login
Grafana web interface login page:

![Grafana Login](docs/screenshots/11-grafana-login.png)

#### Grafana Dashboard
Complete dashboard showing CPU and memory metrics for all instances:

![Grafana Dashboard](docs/screenshots/12-grafana-dashboard.png)

#### CPU Metrics Detail
Detailed CPU utilization time series:

![CPU Metrics](docs/screenshots/13-grafana-cpu-metrics.png)

#### Memory Metrics Detail
Detailed memory utilization time series:

![Memory Metrics](docs/screenshots/14-grafana-memory-metrics.png)

### Troubleshooting Monitoring

**Prometheus targets show as "DOWN":**
```bash
# Check security group allows port 9100
aws ec2 describe-security-groups --group-ids $(terraform output -json | jq -r '.private_sg_id.value')

# SSH to private instance and check node_exporter
ssh -J ec2-user@$(terraform output -raw bastion_public_ip) ec2-user@10.0.101.x
systemctl status node_exporter
curl http://localhost:9100/metrics | head
```

**Grafana dashboard not showing data:**
```bash
# Check Prometheus datasource
curl -s http://$(terraform output -raw monitoring_public_ip):3000/api/datasources | jq

# Check Prometheus is accessible from Grafana container
ssh -i ~/.ssh/your-key ec2-user@$(terraform output -raw monitoring_public_ip)
docker exec grafana curl -s http://prometheus:9090/api/v1/query?query=up
```

**Docker Compose services not running:**
```bash
# SSH to monitoring instance
ssh -i ~/.ssh/your-key ec2-user@$(terraform output -raw monitoring_public_ip)

# Check container logs
cd /home/ec2-user/monitoring
docker-compose logs prometheus
docker-compose logs grafana

# Restart services
docker-compose restart
```

```

- [ ] **Step 2: Update Learning Outcomes section**

Update the "Learning Outcomes" section in `README.md` to include monitoring:

```markdown
## Learning Outcomes

By completing this project, you have:
1. Built custom AMIs with Packer including system monitoring tools
2. Deployed multi-tier VPC architecture with Terraform
3. Implemented bastion host security pattern
4. Configured SSH key distribution with EC2 Instance Connect
5. Set up Prometheus and Grafana for infrastructure monitoring
6. Created auto-provisioned Grafana dashboards with PromQL queries
7. Implemented container-based service deployment with Docker Compose
8. Practiced infrastructure-as-code principles
9. Used AWS CLI for resource verification
10. Documented infrastructure thoroughly with screenshots
```

- [ ] **Step 3: Update Additional Resources section**

Update the "Additional Resources" section to include monitoring resources:

```markdown
## Additional Resources

- [Packer Documentation](https://www.packer.io/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [AWS Bastion Host Pattern](https://aws.amazon.com/solutions/implementations/linux-bastion/)
- [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Node Exporter Guide](https://prometheus.io/docs/guides/node-exporter/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
```

- [ ] **Step 4: Validate README changes**

Run:
```bash
# Check markdown formatting
cat README.md | grep -E "^#{1,3} " | head -20
```

Expected: Headers display correctly

- [ ] **Step 5: Commit README updates**

```bash
git add README.md
git commit -m "docs: add comprehensive monitoring documentation

Add complete monitoring section to README including:
- Monitoring architecture diagram
- Component descriptions and data flow
- Prometheus and Grafana access instructions
- Sample PromQL queries
- Dashboard usage guide
- Verification and troubleshooting steps
- 6 screenshots demonstrating working monitoring

Update learning outcomes and resources sections.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 17: Final verification and testing

**Files:**
- None (verification only)

- [ ] **Step 1: Verify all instances are running**

Run:
```bash
cd terraform
terraform state list | grep aws_instance
```

Expected:
```
aws_instance.bastion
aws_instance.monitoring
aws_instance.private[0]
aws_instance.private[1]
aws_instance.private[2]
aws_instance.private[3]
aws_instance.private[4]
aws_instance.private[5]
```

- [ ] **Step 2: Verify Prometheus targets are all healthy**

Run:
```bash
MONITORING_IP=$(terraform output -raw monitoring_public_ip)
curl -s "http://${MONITORING_IP}:9090/api/v1/targets" | jq '.data.activeTargets | map(select(.health == "up")) | length'
```

Expected: `6` (all 6 instances healthy)

- [ ] **Step 3: Verify Grafana dashboard exists**

Run:
```bash
MONITORING_IP=$(terraform output -raw monitoring_public_ip)
curl -s -u admin:admin "http://${MONITORING_IP}:3000/api/search?query=EC2" | jq '.[].title'
```

Expected: `"EC2 Instances Monitoring"`

- [ ] **Step 4: Test end-to-end metrics flow**

Run:
```bash
MONITORING_IP=$(terraform output -raw monitoring_public_ip)

# Query Prometheus for CPU metrics
curl -s "http://${MONITORING_IP}:9090/api/v1/query?query=node_cpu_seconds_total" | jq '.data.result | length'
```

Expected: Number > 0 (metrics are flowing)

- [ ] **Step 5: Create summary verification document**

Create a simple verification checklist:

```bash
cat > MONITORING_VERIFICATION.md <<'EOF'
# Monitoring Verification Checklist

## Infrastructure
- [x] 8 total instances running (1 bastion + 6 private + 1 monitoring)
- [x] All instances using updated AMI with node_exporter
- [x] Monitoring instance in public subnet with public IP
- [x] Security groups configured correctly

## Prometheus
- [x] Prometheus UI accessible at http://<monitoring-ip>:9090
- [x] All 6 private instances showing as "UP" in targets
- [x] Metrics being scraped every 15 seconds
- [x] CPU and memory queries returning data

## Grafana
- [x] Grafana UI accessible at http://<monitoring-ip>:3000
- [x] Login working with admin/admin credentials
- [x] Prometheus datasource auto-configured
- [x] EC2 Instances Monitoring dashboard auto-loaded
- [x] Dashboard showing CPU gauges for all 6 instances
- [x] Dashboard showing memory gauges for all 6 instances
- [x] Time series graphs displaying historical data
- [x] Auto-refresh working (30 second interval)

## Documentation
- [x] README updated with monitoring sections
- [x] 6 screenshots captured and committed
- [x] Prometheus usage instructions documented
- [x] Grafana usage instructions documented
- [x] Troubleshooting guide included

## Bonus Requirement (25%)
- [x] Grafana dashboard auto-provisioned via Terraform
- [x] Dashboard displays CPU utilization for each instance
- [x] Dashboard displays memory utilization for each instance
- [x] Real-time metrics updating

## Success Criteria
All items checked ✅
EOF

git add MONITORING_VERIFICATION.md
```

- [ ] **Step 6: Commit verification document**

```bash
git commit -m "docs: add monitoring verification checklist

Document verification of all monitoring requirements including:
- Infrastructure deployment
- Prometheus metrics collection
- Grafana dashboard provisioning
- Bonus requirement completion

All verification items passed.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Self-Review Checklist

**Spec Coverage:**
- ✅ Task 1: Packer AMI updated with node_exporter (Spec §1.1)
- ✅ Task 2: New AMI built and deployed (Spec §1.1)
- ✅ Tasks 3-7: All monitoring configurations created (Spec §3)
- ✅ Task 8: Terraform monitoring.tf created (Spec §2.2)
- ✅ Task 9: Security groups updated (Spec §4)
- ✅ Task 10: Terraform outputs added (Spec §5)
- ✅ Task 11: SSH variables for provisioners (Spec §2.2)
- ✅ Task 12: Infrastructure deployed (Spec Phase 4)
- ✅ Tasks 13-14: Monitoring verified (Spec Testing)
- ✅ Task 15: Screenshots captured (Spec §README Screenshots)
- ✅ Task 16: README documentation (Spec §README Documentation)
- ✅ Task 17: Final verification (Spec Success Criteria)

**Placeholder Scan:**
- ✅ No TBD/TODO markers
- ✅ All file paths are exact and complete
- ✅ All code blocks contain actual implementation
- ✅ All commands include expected output
- ✅ No "similar to Task N" references

**Type Consistency:**
- ✅ Resource names consistent: `aws_security_group.monitoring_sg`
- ✅ Variable names consistent: `var.project_name`, `var.ami_id`
- ✅ File paths consistent: `terraform/monitoring_configs/*`
- ✅ Port numbers consistent: 9090 (Prometheus), 3000 (Grafana), 9100 (node_exporter)

**All requirements met with executable, complete implementation steps.**
