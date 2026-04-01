# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.project_name}-bastion-"
  description = "Security group for bastion host - SSH from specific IP only"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name    = "${var.project_name}-bastion-sg"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Bastion SG: SSH ingress from your IP
resource "aws_security_group_rule" "bastion_ssh_ingress" {
  type              = "ingress"
  description       = "SSH from my IP"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${local.my_ip_final}/32"]
  security_group_id = aws_security_group.bastion_sg.id
}

# Bastion SG: SSH egress to private instances
resource "aws_security_group_rule" "bastion_ssh_to_private" {
  type                     = "egress"
  description              = "SSH to private instances"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.private_sg.id
  security_group_id        = aws_security_group.bastion_sg.id
}

# Bastion SG: HTTPS egress for yum updates
resource "aws_security_group_rule" "bastion_https_egress" {
  type              = "egress"
  description       = "HTTPS for package updates"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_sg.id
}

# Bastion SG: HTTP egress for yum updates
resource "aws_security_group_rule" "bastion_http_egress" {
  type              = "egress"
  description       = "HTTP for package updates"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_sg.id
}

# Security Group for Private EC2 Instances
resource "aws_security_group" "private_sg" {
  name_prefix = "${var.project_name}-private-"
  description = "Security group for private EC2 instances - SSH from bastion only"
  vpc_id      = module.vpc.vpc_id

  # SSH ingress from bastion
  ingress {
    from_port                = 22
    to_port                  = 22
    protocol                 = "tcp"
    security_groups          = [aws_security_group.bastion_sg.id]
    description              = "SSH from bastion"
  }

  # Allow Prometheus to scrape node_exporter metrics
  ingress {
    from_port                = 9100
    to_port                  = 9100
    protocol                 = "tcp"
    security_groups          = [aws_security_group.monitoring_sg.id]
    description              = "Allow Prometheus to scrape node_exporter metrics"
  }

  # All traffic within VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "All traffic within VPC"
  }

  tags = {
    Name    = "${var.project_name}-private-sg"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}
