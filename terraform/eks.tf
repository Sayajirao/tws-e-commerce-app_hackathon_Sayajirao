###############################################################################
# EKS cluster + managed node group
#
# REPLICA CHANGES vs. the original repo:
#   * Reuses EXISTING VPC + private subnets (local.vpc_id / local.subnet_ids)
#     instead of module.vpc outputs.
#   * Reuses EXISTING IAM roles (create_iam_role = false) because the power-user
#     SSO role cannot create IAM roles.
#   * Private-only API endpoint (reachable from your VDI inside the network).
#   * KMS secret encryption + CloudWatch log group creation DISABLED (need extra
#     permissions a power-user usually lacks).
#   * remote_access / SSH key removed (no key pair, private nodes).
###############################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  # Endpoint access. Private is always on (VDI reaches it over the TGW). Public is
  # toggled on TEMPORARILY (var.cluster_public_access) so the apps stack — which uses
  # the helm/kubernetes providers and must reach the K8s API — can be applied from a
  # laptop outside the VPC. When public, it is locked to var.cluster_public_access_cidrs
  # (your IP), NOT 0.0.0.0/0. ⚠️ Flip cluster_public_access back to false when done.
  cluster_endpoint_public_access       = var.cluster_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_public_access_cidrs
  cluster_endpoint_private_access      = true

  # Allow the VDI network (outside the VPC, reaching in over the Transit Gateway)
  # to hit the private API endpoint on 443. Without this the cluster security group
  # only permits node<->control-plane traffic, so kubectl from the VDI times out.
  cluster_security_group_additional_rules = {
    vdi_https_ingress = {
      description = "HTTPS to EKS API from VDI network (via TGW)"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [var.vdi_cidr]
    }
  }

  # --- Reuse existing network ------------------------------------------------
  vpc_id                   = local.vpc_id
  subnet_ids               = local.subnet_ids
  control_plane_subnet_ids = local.subnet_ids

  # --- Reuse existing CLUSTER IAM role (do not create) -----------------------
  create_iam_role = false
  iam_role_arn    = local.eks_cluster_role_arn

  # --- Do not create KMS key / CloudWatch log group (perm-restricted) --------
  create_kms_key                   = false
  cluster_encryption_config        = {}
  create_cloudwatch_log_group      = false
  cluster_enabled_log_types        = []
  attach_cluster_encryption_policy = false

  # Grant cluster-admin so kubectl works from the VDI.
  #   * admin_sso  : the SSO role (when authenticating with SSO creds).
  #   * admin_vdi  : the VDI's EC2 instance role. kubectl on the VDI calls
  #     `aws eks get-token` with NO profile, so it authenticates as the instance
  #     role (ecsInstanceRole), not the SSO role. Without this entry the API
  #     server returns "asked for credentials". Survives cluster re-creation.
  authentication_mode = "API_AND_CONFIG_MAP"
  access_entries = {
    admin_sso = {
      principal_arn = local.admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    admin_vdi = {
      principal_arn = var.vdi_instance_role_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  # --- Managed node group ----------------------------------------------------
  eks_managed_node_group_defaults = {
    # Reuse existing node IAM role (do not create)
    create_iam_role = false
    iam_role_arn    = local.eks_node_role_arn

    instance_types = [var.node_instance_type]
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

      # No remote_access block: nodes are private and we have no SSH key pair.

      tags = {
        Name        = "tws-demo-ng"
        Environment = "dev"
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

###############################################################################
# ORIGINAL extra security group for SSH remote access to nodes (commented out):
# not needed — nodes are private and we use no SSH key pair.
###############################################################################
# resource "aws_security_group" "node_group_remote_access" {
#   name   = "allow HTTP"
#   vpc_id = module.vpc.vpc_id
#   ingress {
#     description = "port 22 allow"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     description = "allow all outgoing traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
