# Bastion Host Outputs
output "bastion_public_ip" {
  description = "Public IP address of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_public_dns" {
  description = "Public DNS name of bastion host"
  value       = aws_instance.bastion.public_dns
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host"
  value       = aws_instance.bastion.id
}

# Private Instance Outputs
output "private_instance_ips" {
  description = "Private IP addresses of all private instances"
  value       = aws_instance.private[*].private_ip
}

output "private_instance_ids" {
  description = "Instance IDs of all private instances"
  value       = aws_instance.private[*].id
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

# Connection Information
output "ssh_connection_command" {
  description = "Command to SSH to bastion host"
  value       = "ssh -i ~/.ssh/id_ed25519_jsrahoi-dev ec2-user@${aws_instance.bastion.public_ip}"
}

output "ssh_config_snippet" {
  description = "SSH config snippet for easy access"
  value       = <<-EOT
    # Add to ~/.ssh/config
    Host ${var.project_name}-bastion
      HostName ${aws_instance.bastion.public_ip}
      User ec2-user
      IdentityFile ~/.ssh/id_ed25519_jsrahoi-dev

    Host ${var.project_name}-private-*
      User ec2-user
      IdentityFile ~/.ssh/id_ed25519_jsrahoi-dev
      ProxyJump ${var.project_name}-bastion
  EOT
}

# Detected IP
output "detected_my_ip" {
  description = "Your detected public IP address"
  value       = local.my_ip_final
}
