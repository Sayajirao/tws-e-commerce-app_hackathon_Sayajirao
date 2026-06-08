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

# ---------------------------------------------------------------------------------
# KMS permissions for the EBS CSI driver.
# This account has EBS encryption-by-default ON, using a customer-managed KMS key.
# The default EBS CSI policies grant NO kms: actions, so the driver could create a
# volume but not finalize it with the CMK -> the volume was rejected/cleaned up and
# DescribeVolumes returned "InvalidVolume.NotFound". This policy grants the standard
# EBS-CSI KMS actions so encrypted-by-default volumes provision successfully.
# (The KMS key policy has a `root` allow, so account IAM policies can delegate use.)
# ---------------------------------------------------------------------------------
resource "aws_iam_policy" "ebs_csi_kms" {
  name        = "AmazonEKS_EBS_CSI_KMS_Policy"
  description = "Allow the EBS CSI driver to use the default EBS encryption KMS key"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGenerateDataKeyAndDescribe"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.ebs_kms_key_arn
      },
      {
        Sid      = "AllowCreateGrantForAttachedResources"
        Effect   = "Allow"
        Action   = ["kms:CreateGrant"]
        Resource = var.ebs_kms_key_arn
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_kms" {
  role       = data.aws_iam_role.ebs_csi_driver.name
  policy_arn = aws_iam_policy.ebs_csi_kms.arn
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
