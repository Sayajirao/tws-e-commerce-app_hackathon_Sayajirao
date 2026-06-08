###############################################################################
# Input variables
###############################################################################

variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  default     = "eu-central-1"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Instance type for the EKS managed node group"
  # Bumped t3.large -> t3.xlarge (4 vCPU / 16 GB): the single t3.large could not fit
  # the app + ArgoCD + kube-prometheus-stack + ELK (Elasticsearch/Kibana) at once.
  default = "t3.xlarge"
}

# CIDR allowed to reach the PRIVATE EKS API endpoint (port 443). The VDI sits
# outside the cluster VPC and connects in over the Transit Gateway, so its source
# network must be explicitly allowed on the cluster security group.
#
# Use the whole VDI /16 (not a single host IP): the VDI's address changes on
# reboot / re-provision / pool reassignment, and the cluster may be re-created.
# A /16 keeps kubectl working across all of those without re-whitelisting.
# Observed VDI host: 10.157.139.186  ->  network 10.157.0.0/16.
variable "vdi_cidr" {
  description = "CIDR of the VDI network allowed to reach the EKS API endpoint (443)"
  default     = "10.157.0.0/16"
}

# The VDI authenticates to the cluster as its EC2 instance role (kubectl runs
# `aws eks get-token` with no profile). Grant this role cluster-admin via an EKS
# access entry so kubectl works from the VDI without SSO login. Observed on the
# VDI as: arn:aws:sts::235546316205:assumed-role/ecsInstanceRole/<instance-id>.
variable "vdi_instance_role_arn" {
  description = "ARN of the VDI EC2 instance role granted EKS cluster-admin"
  default     = "arn:aws:iam::235546316205:role/ecsInstanceRole"
}

# TEMPORARY public access to the EKS API endpoint. Default false (private-only). Set
# true only when you need to run the apps stack (helm/kubernetes providers) from a
# machine outside the VPC, then flip back to false. The private endpoint is always on.
variable "cluster_public_access" {
  description = "Enable public access to the EKS API endpoint (temporary; default off)"
  type        = bool
  default     = false
}

# When public access is on, restrict it to these CIDRs (NOT 0.0.0.0/0). Defaults to the
# operator's current public IP. Update if your IP changes.
variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS API when public access is enabled"
  type        = list(string)
  default     = ["223.233.87.24/32"]
}

# --- ORIGINAL (commented out): used only by the Jenkins/Bastion EC2 instances,
#     which we are not creating on private subnets. -----------------------------
# variable "ami_id" {
#   description = "AMI ID for the EC2 instance"
#   default     = "ami-085f9c64a9b75eed5"
# }
#
# variable "instance_type" {
#   description = "Instance type for the EC2 instance"
#   default     = "t3.medium"
# }
#
# variable "my_enviroment" {
#   description = "Environment tag"
#   default     = "dev"
# }
