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

# ARN of the customer-managed KMS key used by EBS encryption-by-default in this account.
# The EBS CSI driver role must be granted use of this key or encrypted volumes fail to
# provision ("InvalidVolume.NotFound"). Get the current default key with:
#   aws ec2 get-ebs-default-kms-key-id --region eu-central-1
variable "ebs_kms_key_arn" {
  description = "ARN of the KMS key used for default EBS volume encryption"
  default     = "arn:aws:kms:eu-central-1:235546316205:key/ea42e7c3-0292-41a3-800d-c759e0f3e30b"
}
