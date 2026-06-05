# ---------------------------------------------------------------------------------
# REUSE existing IAM role (created by a PREVIOUS run; already exists). Referenced
# read-only via a data source to avoid the "EntityAlreadyExists" (409) error.
#
# ⚠️ One-time trust fix needed: the existing role currently trusts an OLD us-west-2
#    cluster OIDC. Run (non-destructive) ONCE before apply:
#      aws iam update-assume-role-policy --role-name AmazonEKS_EBS_CSI_DriverRole \
#        --policy-document file://trust-ebs.json
#    (trust JSON for the CURRENT cluster OIDC is in REPLICA-NOTES.md).
#
# 🔄 To recreate from scratch in a FRESH account: delete the data source below and
#    uncomment the module block.
# ---------------------------------------------------------------------------------
data "aws_iam_role" "ebs_csi_driver" {
  name = "AmazonEKS_EBS_CSI_DriverRole"
}

# module "iam_assumable_role_with_oidc_ebs" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
#   version = "~> 2.0"
#
#   create_role = true
#
#   role_name = "AmazonEKS_EBS_CSI_DriverRole"
#
#   tags = {
#     Role = "role-ebs-csi-driver"
#   }
#
#   # NOTE (replica): was a hardcoded ap-south-1 OIDC URL; now uses the shared variable.
#   provider_url = var.idp_provider_url
#
#   role_policy_arns = [
#     "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
#   ]
# }

module "ebs_csi_driver" {
  source = "../modules/alb_controller"

  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"

  app = {
    name          = "aws-ebs-csi-driver"
    description   = "aws-ebs-csi-driver"
    version       = "2.45.1"
    chart         = "aws-ebs-csi-driver"
    force_update  = true
    wait          = false
    recreate_pods = false
    deploy        = 1
  }
  values = [templatefile("${path.module}/helm-values/ebs-csi-driver-2.45.1.yaml", {
    replicaCount = 1
  })]

  set = [
    {
      name = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      # Reuse the existing role (data source). If recreating from scratch, switch
      # back to: module.iam_assumable_role_with_oidc_ebs.this_iam_role_arn
      value = data.aws_iam_role.ebs_csi_driver.arn
    }
  ]
}
