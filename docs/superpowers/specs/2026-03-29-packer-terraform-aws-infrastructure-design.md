# Packer + Terraform AWS Infrastructure Design

**Date:** 2026-03-29
**Project:** DevOps Spring 2026 - Packer & Terraform Assignment
**Goal:** Create custom AWS AMI with Packer and provision VPC infrastructure with Terraform

## Overview

This project demonstrates infrastructure-as-code principles by creating a custom Amazon Linux AMI with Docker pre-installed using Packer, then deploying a complete VPC architecture with a bastion host and private EC2 instances using Terraform.

## Requirements

- Custom Amazon Linux AMI containing Docker and SSH public key
- VPC with public and private subnets using Terraform modules
- 1 bastion host in public subnet (SSH access restricted to specific IP)
- 6 EC2 instances in private subnet using the custom AMI
- Comprehensive README with screenshots and connection instructions
- GitHub repository using jsrahoi-dev profile

## Architecture

### Component Overview

1. **Packer Component**: Builds immutable AMI with required software
2. **Terraform Component**: Provisions network and compute infrastructure
3. **Connection Flow**: Laptop → Bastion (public) → Private instances (6x)

### Network Design

**VPC Configuration:**
- CIDR: 10.0.0.0/16
- 2 Availability Zones: us-east-1a, us-east-1b
- Region: us-east-1 (N. Virginia)

**Subnets:**
- 2 Public subnets: 10.0.1.0/24 (AZ-a), 10.0.2.0/24 (AZ-b)
- 2 Private subnets: 10.0.101.0/24 (AZ-a), 10.0.102.0/24 (AZ-b)

**Routing:**
- Public subnets: Route to Internet Gateway (0.0.0.0/0 → IGW)
- Private subnets: No internet access (no NAT Gateway)

### Compute Resources

**Bastion Host:**
- Location: Public subnet (us-east-1a)
- Instance type: t2.micro (free tier eligible)
- Public IP: Auto-assigned
- Security: SSH (port 22) from single IP only
- Purpose: SSH jump host to private instances

**Private EC2 Instances:**
- Count: 6 instances
- Location: Distributed across private subnets (3 per subnet)
- Instance type: t2.micro
- Public IP: None
- Security: SSH from bastion security group only
- AMI: Custom Packer-built AMI

## Packer Configuration

### Base Image Selection

**Source AMI:**
- Owner: amazon (verified Amazon images)
- Distribution: Amazon Linux 2023
- Filter: Most recent version matching `al2023-ami-*-x86_64`
- Architecture: x86_64

### Provisioning Steps

The Packer build executes the following provisioning:

1. **System Updates**: `yum update -y` to apply all security patches
2. **Docker Installation**: Install Docker engine via `yum install -y docker`
3. **Docker Service**: Start and enable Docker to run on boot
4. **Docker Compose**: Download and install latest docker-compose binary
5. **User Permissions**: Add ec2-user to docker group (passwordless docker commands)
6. **SSH Key Injection**: Copy SSH public key to `/home/ec2-user/.ssh/authorized_keys`

### Builder Configuration

**Build Instance:**
- Instance type: t2.micro (sufficient for building)
- Region: us-east-1
- SSH username: ec2-user
- Security group: Temporary (auto-created/destroyed)
- Connection: SSH for provisioning

**AMI Output:**
- Name pattern: `devops-packer-docker-{{timestamp}}`
- Tags: Name, Created, Builder, Purpose
- Snapshot: EBS volume included
- AMI ID: Printed to console for Terraform input

### SSH Key Configuration

Uses the jsrahoi-dev SSH public key:
- Path: `/Users/unotest/.ssh/id_ed25519_jsrahoi-dev.pub`
- Injected during provisioning
- Allows passwordless SSH access to all instances

## Terraform Configuration

### Module Strategy

**Official VPC Module:**
- Source: `terraform-aws-modules/vpc/aws` (Terraform Registry)
- Version: Latest stable
- Reason: Proven, well-tested, meets assignment requirement for modules

**Structure:**
```
.
├── main.tf           # EC2 instances, key pair, data sources
├── vpc.tf            # VPC module configuration
├── security_groups.tf # Security group definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output values
├── terraform.tfvars  # User-specific values (gitignored)
└── README.md         # Documentation with screenshots
```

### VPC Module Configuration

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "devops-spring26-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

### Security Groups

**Bastion Security Group:**
- Name: `bastion-sg`
- Ingress: SSH (22/tcp) from detected public IP only
- Egress: SSH (22/tcp) to private-sg (for connecting to private instances)
- Egress: HTTPS (443/tcp) for system updates

**Private Instance Security Group:**
- Name: `private-sg`
- Ingress: SSH (22/tcp) from bastion-sg only
- Egress: None (no internet access, no NAT)

### EC2 Instance Configuration

**Bastion Host:**
```hcl
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type              = "t2.micro"
  subnet_id                  = module.vpc.public_subnets[0]
  vpc_security_group_ids     = [aws_security_group.bastion_sg.id]
  key_name                   = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  tags = {
    Name = "devops-bastion"
  }
}
```

**Private Instances:**
```hcl
resource "aws_instance" "private" {
  count = 6

  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnets[count.index % 2]
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "devops-private-${count.index + 1}"
  }
}
```

### Variables

**Required:**
- `ami_id` - Custom AMI ID from Packer (no default, must provide)

**Optional with Defaults:**
- `aws_region` - Default: "us-east-1"
- `my_ip` - Auto-detected using external data source
- `ssh_public_key_path` - Default: "~/.ssh/id_ed25519_jsrahoi-dev.pub"
- `project_name` - Default: "devops-spring26"
- `private_instance_count` - Default: 6

**IP Auto-Detection:**
```hcl
data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip = chomp(data.http.my_ip.response_body)
}
```

### Outputs

**Connection Information:**
- `bastion_public_ip` - For SSH connection
- `bastion_public_dns` - Alternate connection method
- `ssh_connection_command` - Copy/paste command for bastion
- `ssh_proxy_command` - ProxyJump command for private instances

**Infrastructure Details:**
- `private_instance_ips` - List of all 6 private IPs
- `vpc_id` - VPC identifier
- `public_subnet_ids` - Public subnet identifiers
- `private_subnet_ids` - Private subnet identifiers

## Workflow

### Sequential Execution

**Step 1: Configure GitHub Profile**
```bash
git config user.name "jsrahoi-dev"
git config user.email "<your-email>"
```

**Step 2: Build AMI with Packer**
```bash
cd packer/
packer init .
packer validate amazon-linux-docker.pkr.hcl
packer build amazon-linux-docker.pkr.hcl
```

**Step 3: Capture AMI ID**
Copy the AMI ID from Packer output (e.g., `ami-0123456789abcdef0`)

**Step 4: Configure Terraform**
```bash
cd ../terraform/
cat > terraform.tfvars <<EOF
ami_id = "ami-0123456789abcdef0"
EOF
```

**Step 5: Deploy Infrastructure**
```bash
terraform init
terraform validate
terraform plan
terraform apply
```

**Step 6: Connect to Instances**
```bash
# Connect to bastion
ssh -i ~/.ssh/id_ed25519_jsrahoi-dev ec2-user@<bastion-ip>

# From bastion, connect to private instance
ssh ec2-user@<private-instance-ip>
```

### Why Sequential?

- **Clarity**: Easy to understand and troubleshoot
- **Debugging**: Clear failure points at each step
- **Documentation**: Simple to screenshot and explain
- **Learning**: Demonstrates understanding of both tools
- **Assignment Fit**: Instructor can follow along easily

## Documentation Requirements

### README Content

The project README must include:

1. **Project Overview**: Brief description and architecture diagram
2. **Prerequisites**: AWS credentials, Terraform, Packer versions
3. **Packer Instructions**:
   - How to build the AMI
   - Screenshot of successful build
   - Screenshot of AMI in AWS console
4. **Terraform Instructions**:
   - How to configure variables
   - How to run terraform commands
   - Screenshot of terraform plan
   - Screenshot of terraform apply success
5. **Connection Instructions**:
   - How to SSH to bastion
   - How to SSH from bastion to private instances
   - Screenshot of successful connection
   - Screenshot showing connection to multiple private instances
6. **Architecture Diagram**: Visual representation of VPC, subnets, instances
7. **Cleanup Instructions**: How to destroy all resources

### Screenshots to Capture

**Packer:**
- Packer build in progress
- Packer build success with AMI ID
- AWS console showing the new AMI

**Terraform:**
- `terraform plan` output
- `terraform apply` completion
- AWS console showing VPC and subnets
- AWS console showing bastion and private instances
- Security group rules

**Connectivity:**
- SSH connection to bastion
- SSH from bastion to private instance
- Running `docker --version` on instances
- Output of `ip addr` showing private IPs

## File Organization

```
devops-spring26-packer-terraform/
├── README.md
├── .gitignore
├── packer/
│   ├── amazon-linux-docker.pkr.hcl
│   └── variables.pkr.hcl
├── terraform/
│   ├── main.tf
│   ├── vpc.tf
│   ├── security_groups.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── .gitignore
├── docs/
│   ├── screenshots/
│   │   ├── packer-build.png
│   │   ├── ami-console.png
│   │   ├── terraform-plan.png
│   │   ├── terraform-apply.png
│   │   ├── aws-vpc.png
│   │   ├── aws-instances.png
│   │   └── ssh-connection.png
│   └── architecture-diagram.png
└── .github/
    └── workflows/
        └── (optional CI/CD)
```

## Security Considerations

**SSH Access:**
- Bastion only accepts connections from single IP
- Private instances only accept connections from bastion
- No password authentication (key-based only)

**Network Isolation:**
- Private instances have no internet access
- Prevents outbound data exfiltration
- Limits attack surface

**Credentials:**
- No hardcoded credentials in code
- terraform.tfvars in .gitignore
- AWS credentials from environment/profile

**AMI Security:**
- Only official Amazon Linux base images
- Regular yum updates during build
- Minimal software installation

## Testing Strategy

**Packer Validation:**
1. Verify AMI appears in AWS console
2. Launch test instance from AMI manually
3. Confirm Docker is installed and running
4. Verify SSH key authentication works

**Terraform Validation:**
1. Run `terraform validate` before apply
2. Review `terraform plan` output carefully
3. Verify resource count matches expected (1 bastion, 6 private)
4. Check security group rules in AWS console

**Connectivity Testing:**
1. SSH to bastion from local machine
2. From bastion, SSH to each private instance
3. Run `docker --version` to verify installation
4. Check instance metadata to confirm private subnet placement

**Cleanup Verification:**
1. Run `terraform destroy`
2. Verify all EC2 instances terminated
3. Verify VPC and subnets deleted
4. Manually deregister AMI from AWS console

## Success Criteria

- Packer successfully creates AMI with Docker installed
- Terraform deploys VPC with correct CIDR and subnets
- Bastion host has public IP and accepts SSH from your IP
- All 6 private instances deploy in private subnets
- SSH authentication works with jsrahoi-dev key
- Can connect from bastion to all private instances
- Docker runs without sudo on all instances
- README includes all required screenshots
- Infrastructure can be destroyed cleanly with `terraform destroy`

## Future Enhancements (Out of Scope)

- Automated testing with Terratest
- CI/CD pipeline for infrastructure changes
- Configuration management with Ansible
- Monitoring and logging with CloudWatch
- Auto-scaling for private instances
- Application deployment to instances
