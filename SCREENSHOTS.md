# Required AWS Console Screenshots

This document lists all required screenshots to complete the project documentation.

## Screenshot Checklist

### 1. AMI Console Screenshot
**Filename**: `screenshots/01-ami-console.png`

**Instructions**:
1. Navigate to AWS Console → EC2 → AMIs
2. Select region: us-east-1
3. Filter: Owned by me
4. Ensure your custom AMI is visible: `devops-packer-docker-20260329212457` (ami-0302f27ad103a0858)
5. Capture screenshot showing:
   - AMI ID
   - AMI Name
   - Status (should be "available")
   - Creation date

---

### 2. VPC Dashboard Screenshot
**Filename**: `screenshots/02-aws-vpc.png`

**Instructions**:
1. Navigate to AWS Console → VPC → Your VPCs
2. Select the VPC: `devops-spring26-vpc` (vpc-08a56eb76b1c4a09a)
3. Capture screenshot showing:
   - VPC ID
   - CIDR block (10.0.0.0/16)
   - DNS hostnames: Enabled
   - DNS resolution: Enabled

---

### 3. Subnets Screenshot
**Filename**: `screenshots/03-aws-subnets.png`

**Instructions**:
1. Navigate to AWS Console → VPC → Subnets
2. Filter by VPC: `devops-spring26-vpc`
3. Capture screenshot showing all 4 subnets:
   - Public Subnet 1 (us-east-1a): 10.0.1.0/24
   - Public Subnet 2 (us-east-1b): 10.0.2.0/24
   - Private Subnet 1 (us-east-1a): 10.0.101.0/24
   - Private Subnet 2 (us-east-1b): 10.0.102.0/24

---

### 4. EC2 Instances Screenshot
**Filename**: `screenshots/04-aws-instances.png`

**Instructions**:
1. Navigate to AWS Console → EC2 → Instances
2. Capture screenshot showing all 7 instances:
   - 1 bastion instance (with public IP)
   - 6 private instances (no public IP)
3. Ensure visible columns show:
   - Instance ID
   - Name
   - Instance state (all should be "running")
   - Instance type (all t2.micro)
   - Private IP
   - Public IP (only bastion should have one)

---

### 5. Security Groups Screenshot
**Filename**: `screenshots/05-aws-security-groups.png`

**Instructions**:
1. Navigate to AWS Console → EC2 → Security Groups
2. Filter by VPC: `devops-spring26-vpc`
3. Capture screenshot showing:
   - `devops-spring26-bastion-sg`
   - `devops-spring26-private-sg`
4. Click on bastion SG and capture inbound/outbound rules
5. Click on private SG and capture inbound/outbound rules

**Alternative**: Create two separate screenshots:
- `05a-bastion-sg.png` - Bastion security group rules
- `05b-private-sg.png` - Private security group rules

---

### 6. Bastion SSH Connection Screenshot
**Filename**: `screenshots/06-bastion-ssh.png`

**Instructions**:
1. Open terminal
2. Run: `ssh -i ~/.ssh/id_ed25519_jsrahoi-dev ec2-user@3.215.135.8`
3. Run commands to show:
   ```bash
   echo "Bastion SSH Test"
   hostname
   uptime
   whoami
   ip addr show
   ```
4. Capture screenshot showing successful connection and command output

---

### 7. Private Instance SSH Connection Screenshot
**Filename**: `screenshots/07-private-ssh.png`

**Instructions**:
1. Open terminal
2. Connect to a private instance via ProxyJump:
   ```bash
   ssh -i ~/.ssh/id_ed25519_jsrahoi-dev -J ec2-user@3.215.135.8 ec2-user@10.0.101.191
   ```
3. Run commands to show:
   ```bash
   echo "Private Instance SSH Test"
   hostname
   docker --version
   docker ps
   systemctl status docker --no-pager -l
   ```
4. Capture screenshot showing successful connection and Docker installation

---

### 8. All Private Instances Test Screenshot
**Filename**: `screenshots/08-all-private-ips.png`

**Instructions**:
1. Open terminal
2. Run this script to test all 6 private instances:
   ```bash
   for ip in 10.0.101.191 10.0.102.27 10.0.101.95 10.0.102.231 10.0.101.221 10.0.102.33; do
     echo "=== Testing $ip ==="
     ssh -i ~/.ssh/id_ed25519_jsrahoi-dev \
         -o StrictHostKeyChecking=no \
         -J ec2-user@3.215.135.8 \
         ec2-user@$ip \
         "hostname && docker --version"
   done
   ```
3. Capture screenshot showing all 6 instances tested successfully

---

## Screenshot Storage

Create a `screenshots/` directory in your project:

```bash
mkdir -p screenshots
```

After capturing screenshots, verify you have all 8 files:

```bash
ls -la screenshots/
```

Expected files:
```
01-ami-console.png
02-aws-vpc.png
03-aws-subnets.png
04-aws-instances.png
05-aws-security-groups.png
06-bastion-ssh.png
07-private-ssh.png
08-all-private-ips.png
```

## Adding to Git

Once screenshots are captured, add them to git:

```bash
git add screenshots/
git commit -m "Add AWS Console and SSH verification screenshots"
```

## Screenshot Quality Guidelines

- Use full-screen or maximized browser/terminal windows
- Ensure text is readable (minimum 12pt font for terminals)
- Show relevant information without sensitive data (except IPs which are temporary)
- Use high-quality PNG format
- Crop to show only relevant portions (remove unnecessary UI chrome)

## Notes

- Screenshots document the successful deployment
- Useful for presentations or portfolio
- Can be referenced in README.md
- IPs shown in screenshots will change if infrastructure is redeployed
