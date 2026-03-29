# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.project_name}-bastion-"
  description = "Security group for bastion host - SSH from specific IP only"
  vpc_id      = module.vpc.vpc_id

  # SSH from your IP only
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  # Allow outbound to private instances on SSH
  egress {
    description     = "SSH to private instances"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.private_sg.id]
  }

  # Allow outbound HTTPS for yum updates
  egress {
    description = "HTTPS for package updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound HTTP for yum updates
  egress {
    description = "HTTP for package updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-bastion-sg"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Private EC2 Instances
resource "aws_security_group" "private_sg" {
  name_prefix = "${var.project_name}-private-"
  description = "Security group for private EC2 instances - SSH from bastion only"
  vpc_id      = module.vpc.vpc_id

  # SSH from bastion only
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # No outbound internet access (no NAT gateway)
  # Only allow communication within VPC
  egress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name    = "${var.project_name}-private-sg"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}
