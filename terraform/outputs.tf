###############################################################################
# Outputs
###############################################################################

output "region" {
  description = "The AWS region where resources are created"
  value       = local.region
}

output "vpc_id" {
  description = "The ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets (host internet-facing ALBs + Jenkins/Bastion)"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnets (EKS control plane + nodes)"
  value       = module.vpc.private_subnets
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "update_kubeconfig_command" {
  description = "Run this to configure kubectl"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "jenkins_url" {
  description = "Jenkins URL (Elastic IP, port 8080)"
  value       = "http://${aws_eip.jenkins_server_ip.public_ip}:8080"
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion host (SSH with terra-key.pem)"
  value       = aws_instance.bastion_host.public_ip
}

output "ssh_private_key_file" {
  description = "Path to the auto-generated SSH private key"
  value       = local_file.deployer_private_key.filename
}
