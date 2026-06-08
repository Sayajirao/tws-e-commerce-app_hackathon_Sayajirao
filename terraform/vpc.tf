###############################################################################
# VPC  --  CREATED IN THIS (PERSONAL) ACCOUNT
#
# Real VPC with public + private subnets across 2 AZs, a single NAT gateway for
# private-subnet egress, and an internet gateway for the public subnets. Subnets
# are tagged so the AWS Load Balancer Controller can auto-discover them:
#   * public  -> kubernetes.io/role/elb            (internet-facing ALBs)
#   * private -> kubernetes.io/role/internal-elb   (internal ALBs / nodes)
###############################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.18.1"

  name            = local.name
  cidr            = local.vpc_cidr
  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Required for the EKS control plane / nodes to resolve and register correctly.
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"              = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"     = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  # Public subnets auto-assign public IPs (so public-subnet EC2 like Jenkins are reachable).
  map_public_ip_on_launch = true

  tags = local.tags
}
