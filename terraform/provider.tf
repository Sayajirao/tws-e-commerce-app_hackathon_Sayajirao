###############################################################################
# Global settings (region, names, networking)
#
# NOTE (replica): We are NOT creating a VPC/subnets in this account. We reuse an
# existing VPC + private subnets. The original public/private subnet CIDRs from
# the source repo are kept below but COMMENTED OUT for reference only.
###############################################################################

locals {
  region = "eu-central-1"
  name   = "tws-eks-cluster"

  # --- Existing network we are REUSING (provided by the account owner) ---
  vpc_id = "vpc-0e5e46dbfb0bba139"
  subnet_ids = [
    "subnet-0ad263edef26a51fd", # eu-central-1a (private)
    "subnet-0b317785ff8946260", # eu-central-1c (private)
  ]

  # --- Existing IAM roles we are REUSING (power-user SSO cannot create roles) ---
  eks_cluster_role_arn = "arn:aws:iam::235546316205:role/AmazonEKSClusterRole"
  eks_node_role_arn    = "arn:aws:iam::235546316205:role/AmazonEKSNodeRole"

  # Your SSO permission-set role, granted cluster-admin so kubectl works from VDI.
  admin_principal_arn = "arn:aws:iam::235546316205:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_common-usecase-pwrusr_ea416c7a30a3ccec"

  # ----------------------------------------------------------------------------
  # ORIGINAL (commented out): we do not create a VPC, so these are unused.
  # vpc_cidr        = "10.0.0.0/16"
  # azs             = ["eu-west-1a", "eu-west-1b"]
  # public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  # private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  # ----------------------------------------------------------------------------

  tags = {
    example = local.name
  }
}

provider "aws" {
  region = local.region
}
