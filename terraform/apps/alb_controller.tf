# ---------------------------------------------------------------------------------
# REUSE existing IAM (the policy + role were created by a PREVIOUS run of this
# project and already exist in the account). We reference them read-only via data
# sources instead of creating them, to avoid "EntityAlreadyExists" (409) errors.
#
# ⚠️ One-time trust fix needed: the existing role's trust policy points at an OLD
#    cluster's OIDC. Run (non-destructive, edits trust only) ONCE before apply:
#      aws iam update-assume-role-policy --role-name AmazonEKSLoadBalancerControllerRole \
#        --policy-document file://trust-alb.json
#    (trust JSON for the CURRENT cluster OIDC is in REPLICA-NOTES.md).
#
# 🔄 To recreate everything from scratch in a FRESH account instead, delete the two
#    data sources below and uncomment the resource + module blocks.
# ---------------------------------------------------------------------------------
data "aws_iam_policy" "alb_policy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
}

data "aws_iam_role" "alb_controller" {
  name = "AmazonEKSLoadBalancerControllerRole"
}

# resource "aws_iam_policy" "alb_policy" {
#   name   = "AWSLoadBalancerControllerIAMPolicy"
#   path   = "/"
#   policy = file("iam_policy.json")
# }
# module "iam_assumable_role_with_oidc" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
#   version = "~> 2.0"
#
#   create_role = true
#
#   role_name = "AmazonEKSLoadBalancerControllerRole"
#
#   tags = {
#     Role = "role-alb-controller"
#   }
#
#   # NOTE (replica): was a hardcoded ap-south-1 OIDC URL; now uses the shared variable.
#   provider_url = var.idp_provider_url
#
#   role_policy_arns = [
#     aws_iam_policy.alb_policy.arn,
#   ]
# }

module "alb_controller" {
  source = "../modules/alb_controller"

  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"

  app = {
    name          = "aws-load-balancer-controller"
    description   = "aws-load-balancer-controller"
    version       = "1.13.3"
    chart         = "aws-load-balancer-controller"
    force_update  = true
    wait          = false
    recreate_pods = false
    deploy        = 1
  }
  values = [templatefile("${path.module}/helm-values/alb_controller-1.13.3.yaml", {
    replicaCount = 1
  })]

  set = [
    {
      name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      # Reuse the existing role (data source). If recreating from scratch, switch
      # back to: module.iam_assumable_role_with_oidc.this_iam_role_arn
      value = data.aws_iam_role.alb_controller.arn
    }
  ]

}
