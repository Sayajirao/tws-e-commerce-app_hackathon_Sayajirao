# ---------------------------------------------------------------------------------
# CREATE IAM from scratch (personal account).
# We create the ALB controller's IAM policy (from iam_policy.json, which already
# includes the newer actions the v1.13.x controller needs, e.g.
# DescribeListenerAttributes) and an IRSA role bound to the controller's service
# account via the cluster OIDC provider (var.idp_provider_url).
#
# ⚠️ Two-stage apply: var.idp_provider_url must be set to the cluster's OIDC issuer
#    AFTER the root stack creates the cluster. See DEPLOY-PERSONAL-ACCOUNT.md §2.
# ---------------------------------------------------------------------------------
resource "aws_iam_policy" "alb_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  path   = "/"
  policy = file("iam_policy.json")
}

module "iam_assumable_role_with_oidc" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role = true
  role_name   = "AmazonEKSLoadBalancerControllerRole"

  tags = {
    Role = "role-alb-controller"
  }

  provider_url = var.idp_provider_url

  role_policy_arns = [
    aws_iam_policy.alb_policy.arn,
  ]

  # Bind the role to the controller's service account.
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:aws-load-balancer-controller",
  ]
}

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
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.iam_assumable_role_with_oidc.iam_role_arn
    }
  ]
}
