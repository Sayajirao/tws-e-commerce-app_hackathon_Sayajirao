###############################################################################
# Global settings (region, names, networking)
#
# PERSONAL ACCOUNT: we create our OWN VPC + subnets + IAM from scratch (the
# earlier Roche-account constraints — reuse-only VPC/IAM, private endpoint, etc.
# — do not apply here). The VPC itself is defined in vpc.tf (module.vpc).
###############################################################################

locals {
  region = var.aws_region
  name   = "tws-eks-cluster"

  # --- Network we CREATE (see vpc.tf / module.vpc) ---------------------------
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  tags = {
    example = local.name
  }
}

provider "aws" {
  region = local.region
}
