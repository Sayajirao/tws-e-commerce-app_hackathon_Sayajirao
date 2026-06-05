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
  default     = "t3.large"
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
