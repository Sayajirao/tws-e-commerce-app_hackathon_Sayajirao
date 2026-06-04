###############################################################################
# Outputs
###############################################################################

output "region" {
  description = "The AWS region where resources are created"
  value       = local.region
}

output "vpc_id" {
  description = "The ID of the (existing) VPC being used"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "The (existing) subnets the cluster runs in"
  value       = local.subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint (private)"
  value       = module.eks.cluster_endpoint
}

output "update_kubeconfig_command" {
  description = "Run this from your VDI to configure kubectl"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins server (reach it from the VDI: http://<ip>:8080)"
  value       = aws_instance.testinstance.private_ip
}

output "bastion_private_ip" {
  description = "Private IP of the Bastion host (SSH from the VDI using terra-key.pem)"
  value       = aws_instance.bastion_host.private_ip
}

output "ssh_private_key_file" {
  description = "Path to the auto-generated SSH private key"
  value       = local_file.deployer_private_key.filename
}
