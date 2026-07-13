# OIDC provider URL of the EKS cluster (used for IRSA roles: ALB controller + EBS CSI).
# ⚠️ TWO-STAGE APPLY: set this AFTER the root `terraform apply` creates the cluster +
# OIDC provider. Get the value with:
#   aws eks describe-cluster --name tws-eks-cluster --region ap-south-1 \
#     --query "cluster.identity.oidc.issuer" --output text
# It looks like: oidc.eks.ap-south-1.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Strip the leading "https://" — the IRSA module expects the bare host/path form.
variable "idp_provider_url" {
  description = "Bare OIDC provider URL (no https://) of the EKS cluster, for IRSA"
  default     = "oidc.eks.ap-south-1.amazonaws.com/id/DB8FB44FDCBF025490AC25E10296B4C0"
}
