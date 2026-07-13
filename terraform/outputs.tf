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

# NOTE: Jenkins + Bastion EC2 outputs were removed. CI now runs on GitHub Actions
# (off-cluster) and CD is handled by Argo CD in-cluster, so there are no EC2 hosts.
# kubectl reaches the cluster via the public EKS endpoint locked to your IP.
