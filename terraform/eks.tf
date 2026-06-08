###############################################################################
# EKS cluster + managed node group  --  PERSONAL ACCOUNT (create from scratch)
#
#   * Creates its OWN cluster + node IAM roles (create_iam_role = true).
#   * Uses the VPC + subnets we create in vpc.tf (module.vpc):
#       - control plane + nodes run in the PRIVATE subnets
#       - public subnets (tagged kubernetes.io/role/elb) host internet-facing ALBs
#   * PUBLIC API endpoint, locked to var.cluster_public_access_cidrs (your IP),
#     so kubectl + the apps stack run straight from your laptop. Private also on.
#   * IRSA (OIDC provider) enabled for the add-on service accounts.
###############################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  # Public endpoint locked to your IP (private endpoint stays on for in-VPC traffic).
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_public_access_cidrs
  cluster_endpoint_private_access      = true

  # OIDC provider for IRSA (required by the ALB controller / EBS CSI service accounts).
  enable_irsa = true

  # --- Network we created in vpc.tf ------------------------------------------
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # --- Create cluster IAM role (personal account can create IAM) -------------
  create_iam_role = true

  # Grant the identity running Terraform cluster-admin so kubectl works immediately.
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  # --- Managed node group ----------------------------------------------------
  eks_managed_node_group_defaults = {
    create_iam_role = true
    instance_types  = [var.node_instance_type]
  }

  eks_managed_node_groups = {
    tws-demo-ng = {
      min_size     = 1
      max_size     = 4
      desired_size = 2 # 2x t3.xlarge to fit app + argocd + prometheus + ELK

      instance_types = [var.node_instance_type]
      capacity_type  = "SPOT"

      disk_size                  = 35
      use_custom_launch_template = false # Important to apply disk size!

      tags = {
        Name        = "tws-demo-ng"
        Environment = var.my_enviroment
        ExtraTag    = "e-commerce-app"
      }
    }
  }

  tags = local.tags
}

# Discover the running node instances (used by outputs.tf).
data "aws_instances" "eks_nodes" {
  instance_tags = {
    "eks:cluster-name" = module.eks.cluster_name
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.eks]
}
