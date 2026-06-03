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
