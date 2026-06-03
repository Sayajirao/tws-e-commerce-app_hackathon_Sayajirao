###############################################################################
# VPC  --  DISABLED IN THIS ACCOUNT
#
# We are NOT allowed to create a VPC here. Instead we reuse the existing VPC and
# private subnets defined in provider.tf (local.vpc_id / local.subnet_ids).
#
# The entire original VPC module is kept below, COMMENTED OUT, for reference and
# in case this is ever run in an account where VPC creation is permitted.
###############################################################################

# module "vpc" {
#
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 5.18.1"
#
#   name            = local.name
#   cidr            = local.vpc_cidr
#   azs             = local.azs
#   public_subnets  = local.public_subnets
#   private_subnets = local.private_subnets
#
#   enable_nat_gateway     = true
#   single_nat_gateway     = true
#   one_nat_gateway_per_az = false
#
#   public_subnet_tags = {
#     "kubernetes.io/role/elb" = 1
#   }
#
#   private_subnet_tags = {
#     "kubernetes.io/role/internal-elb" = 1
#   }
#
#   # Ensure public subnets auto-assign public IPs
#   map_public_ip_on_launch = true
# }
