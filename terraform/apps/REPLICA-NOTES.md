# terraform/apps — Replica Notes

These Helm add-ons (ALB controller, EBS CSI driver, ArgoCD, kube-prometheus-stack)
install **into** the EKS cluster. They can only be applied **after** the root
`../` Terraform has created the cluster + OIDC provider, and after your kubeconfig
points at it (`aws eks update-kubeconfig ... --name tws-eks-cluster`).

## ⚠️ Apply order
1. `cd ..` → `terraform apply` (creates cluster + OIDC provider). **Must succeed first.**
2. `aws eks --region eu-central-1 update-kubeconfig --name tws-eks-cluster`
3. `cd apps` → fill in the TODOs below → `terraform init && terraform apply`

## ✅ Adaptations already made (vs. the original repo)
- `terraform.tf`: provider region `ap-south-1` → `eu-central-1`.
- `variables.tf`: `idp_provider_url` default now points at eu-central-1 with a
  placeholder OIDC id (see TODO #1).
- `alb_controller.tf` / `ebs_csi_driver.tf`: hardcoded ap-south-1 OIDC URLs replaced
  with `var.idp_provider_url` (single source of truth).
- `helm-values/alb_controller-1.13.3.yaml`: `region` → eu-central-1; `vpcId` → the
  reused VPC `vpc-0e5e46dbfb0bba139`.

## 🔧 TODOs you MUST fill before applying (values only known post-cluster)
1. **OIDC provider id** — `variables.tf` → `idp_provider_url`. Get it with:
   ```bash
   aws eks describe-cluster --name tws-eks-cluster --region eu-central-1 \
     --query "cluster.identity.oidc.issuer" --output text
   ```
   Use the bare form (strip `https://`): `oidc.eks.eu-central-1.amazonaws.com/id/XXXX`.

2. **IRSA roles — NOW REUSING EXISTING ROLES (updated 2026-06-06).** The IAM policy +
   both roles already exist from a PREVIOUS run (created Jan 2026):
   `AWSLoadBalancerControllerIAMPolicy`, `AmazonEKSLoadBalancerControllerRole`,
   `AmazonEKS_EBS_CSI_DriverRole`. A fresh `create_role = true` apply failed with
   `EntityAlreadyExists` (409). So `alb_controller.tf` + `ebs_csi_driver.tf` now reference
   them **read-only via `data` sources** (create blocks are COMMENTED OUT, not deleted —
   uncomment to recreate from scratch in a fresh account).

   ⚠️ **One-time trust fix required before apply.** The existing roles' trust policies
   point at OLD/wrong OIDC (ALB → Pod-Identity `pods.eks.amazonaws.com`; EBS → a dead
   **us-west-2** cluster). The CURRENT cluster OIDC is
   `oidc.eks.eu-central-1.amazonaws.com/id/36BC109CD692D28616F3FDDBDAEA8E50`. Fix is
   NON-DESTRUCTIVE (edits trust doc only, does not delete the role). Run ONCE:
   ```bash
   aws iam update-assume-role-policy --role-name AmazonEKSLoadBalancerControllerRole \
     --policy-document file://trust-alb.json
   aws iam update-assume-role-policy --role-name AmazonEKS_EBS_CSI_DriverRole \
     --policy-document file://trust-ebs.json
   ```
   (`trust-alb.json` / `trust-ebs.json` are in this dir, pre-filled for the current
   cluster OIDC + the correct service-account subjects.) The OIDC provider IS registered
   in IAM, so IRSA works once trust is fixed. If the cluster is ever recreated, the OIDC
   id changes → regenerate these two JSON files with the new id.

3. **ArgoCD / Grafana ingress certs (optional)** — `helm-values/argocd-values.yaml` and
   `helm-values/kube-prom-stack.yaml` contain a hardcoded ACM cert ARN + account from the
   original author (`ap-south-1 / 876997124628`). These only matter if you expose those
   UIs via ALB ingress. Replace with your own cert ARN/domain, or disable those ingress
   blocks and use `kubectl port-forward` instead.

## 🗂️ Unreferenced helm-values files (left in place, NOT used by any .tf)
`alb-controller.yaml`, `ebs-driver.yaml`, `elasticsearch.yaml`, `filebeat.yaml`,
`kibana.yaml`, `storageclass.yaml`, top-level `iam_policy.json` duplicate.
> `ebs-driver.yaml` contains the original author's account id in a sample role-arn —
> it is inert (unreferenced) but don't copy values out of it. Safe to delete these
> if you want a cleaner dir; kept for now for parity with the source repo.

## Backend / state
This stack currently has **no backend block** → it uses local state
(`terraform.tfstate` in this dir, gitignored). If you want it in S3 like the root
stack, add a `backend "s3"` block with a separate key (e.g. `eks/apps.tfstate`).
