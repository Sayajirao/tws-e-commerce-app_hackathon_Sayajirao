###############################################################################
# Input variables
###############################################################################

variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  default     = "ap-south-1"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Instance type for the EKS managed node group"
  # t3.xlarge (4 vCPU / 16 GB): fits app + ArgoCD + kube-prometheus-stack + ELK.
  default = "t3.xlarge"
}

# CIDRs allowed to reach the PUBLIC EKS API endpoint (port 443). Locked to the
# operator's current public IP rather than 0.0.0.0/0. Update if your IP changes
# (find it with: curl checkip.amazonaws.com).
variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = ["223.233.80.129/32"]
}

variable "my_enviroment" {
  description = "Environment tag"
  default     = "dev"
}
