# OIDC provider URL of the EKS cluster (used for IRSA roles for ALB controller + EBS CSI).
# TODO (replica): set this AFTER the root `terraform apply` creates the cluster + OIDC
# provider. Get the value with:
#   aws eks describe-cluster --name tws-eks-cluster --region eu-central-1 \
#     --query "cluster.identity.oidc.issuer" --output text
# It looks like: oidc.eks.eu-central-1.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Strip the leading "https://" — the IRSA module expects the bare host/path form below.
variable "idp_provider_url" {
  description = "Bare OIDC provider URL (no https://) of the EKS cluster, for IRSA"
  default     = "oidc.eks.eu-central-1.amazonaws.com/id/REPLACE-WITH-YOUR-OIDC-ID"
}
