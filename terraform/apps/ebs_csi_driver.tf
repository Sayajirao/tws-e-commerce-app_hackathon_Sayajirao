# ---------------------------------------------------------------------------------
# CREATE IAM from scratch (personal account).
# IRSA role for the EBS CSI driver, bound to its service account via the cluster
# OIDC provider, with AWS's managed AmazonEBSCSIDriverPolicy attached.
#
# NOTE: the Roche account needed an EXTRA customer-managed-KMS policy because it
# had EBS encryption-by-default with a CMK. A personal account uses the AWS-managed
# aws/ebs key by default, which the managed policy already covers — so no extra
# KMS policy is needed here. (If you later enable a CMK for EBS, add a kms: policy.)
# ---------------------------------------------------------------------------------
module "iam_assumable_role_with_oidc_ebs" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role = true
  role_name   = "AmazonEKS_EBS_CSI_DriverRole"

  tags = {
    Role = "role-ebs-csi-driver"
  }

  provider_url = var.idp_provider_url

  role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:ebs-csi-controller-sa",
  ]
}

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
      name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.iam_assumable_role_with_oidc_ebs.iam_role_arn
    }
  ]
}
