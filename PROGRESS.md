# 📋 Project Progress — EasyShop on EKS

> **Purpose:** Daily progress tracker + context file. At the start of any session,
> read this file to get fully caught up. At the end of a session, update it.

---

## 🎯 Goal
Replicate the **EasyShop** full-stack e-commerce app (Next.js + MongoDB) and deploy it
on **AWS EKS**, building the DevOps stack step by step as a portfolio project.
Source reference repo: `../tws-e-commerce-app_hackathon` (the original clone).

---

## 🔑 Environment Facts (do not lose these)

| Item | Value |
|------|-------|
| AWS Account | `235546316205` |
| Region | `eu-central-1` |
| Auth | AWS **SSO** role `AWSReservedSSO_common-usecase-pwrusr` (temp creds, expire daily) |
| SSO admin role ARN | `arn:aws:iam::235546316205:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_common-usecase-pwrusr_ea416c7a30a3ccec` |
| **Existing VPC** (reused) | `vpc-0e5e46dbfb0bba139` (CIDR `10.174.62.0/24` + secondaries) |
| **Subnet A** (eu-central-1a, private) | `subnet-0ad263edef26a51fd` |
| **Subnet C** (eu-central-1c, private) | `subnet-0b317785ff8946260` |
| Internet egress | via Transit Gateway `tgw-0cacc4d4bea21e576` (no NAT/IGW) |
| **Existing IAM roles** (reused) | `AmazonEKSClusterRole`, `AmazonEKSNodeRole` |
| Terraform state | S3 bucket `k8s-buckettttt`, key `eks/terraform.tfstate` |
| Cluster name | `tws-eks-cluster` (k8s v1.31) |
| GitHub repo | `github.com/Sayajirao/tws-e-commerce-app_hackathon_Sayajirao` |

---

## ⚙️ Key Decisions & Constraints (the "why")

- **Cannot create a VPC** in this account → reuse existing VPC/subnets via Terraform
  `locals` (`local.vpc_id`, `local.subnet_ids`) instead of the original `module.vpc`.
- **Power-user SSO likely cannot create IAM roles** → reuse existing
  `AmazonEKSClusterRole` + `AmazonEKSNodeRole` (`create_iam_role = false`).
- **Private-only API endpoint** (`cluster_endpoint_public_access = false`) — reached
  from the **VDI** inside the VPC network. `kubectl` only works from the VDI.
- **EC2 (Jenkins + Bastion) placed in private subnets** (user can reach via VDI/browser).
  SSH key auto-generated → `terraform/terra-key.pem` (gitignored, never commit).
- **KMS encryption + CloudWatch log group DISABLED** (extra perms a power-user lacks).
- **OIDC provider (`enable_irsa`) still ON** — needs `iam:CreateOpenIDConnectProvider`.
  ⚠️ UNVERIFIED whether the role can create it. If `apply` fails here, set
  `enable_irsa = false` and re-enable at the Helm add-ons stage.

---

## ✅ Done

- [x] Understood original repo (app, Docker, k8s/, terraform/, helm-values/, CI/CD).
- [x] Inspected AWS account (VPC, subnets, routing, IAM roles, S3 bucket) — all verified.
- [x] Wrote `terraform/` replica reusing existing VPC/subnets/roles:
  - `provider.tf` (locals), `terraform.tf` (S3 backend + providers), `variables.tf`
  - `vpc.tf` (original module commented out), `eks.tf` (cluster + node group)
  - `ec2.tf` (Jenkins, private subnet, auto SSH key), `bastion_ec2.tf` (private)
  - `install_tools.sh`, `bastion_user_data.sh`, `outputs.tf`
- [x] `terraform init` (S3 migrate) + `validate` + `plan` all succeed → **31 to add**.
- [x] Added `.gitignore` (excludes terra-key.pem, .terraform/, *.tfstate).

---

## 🔜 Next Steps

- [ ] Commit work in 4 logical commits on branch `feat/terraform-eks`, open PR, merge.
- [ ] `terraform apply` (from VDI). Watch the OIDC provider step (see constraint above).
- [ ] After apply: `aws eks --region eu-central-1 update-kubeconfig --name tws-eks-cluster`
      then `kubectl get nodes` (from VDI).
- [ ] Replicate `kubernetes/` manifests (namespace → mongodb → app → service → ingress
      → hpa → migration job), adapting image names / domain / certs.
- [ ] Replicate `terraform/apps/` Helm add-ons (ALB controller, EBS CSI, ArgoCD,
      kube-prometheus-stack) — re-enable IRSA here, fix OIDC ID + region.
- [ ] CI/CD (Jenkins on the EC2 we created, or GitHub Actions).
- [ ] Logging stack (ELK) — optional.
- [ ] Polish README + architecture diagram for the portfolio.

---

## 🛠️ Daily Startup Routine

```bash
# 1. Refresh AWS SSO creds (they expire daily)
aws sso login --profile <your-sso-profile>
export AWS_PROFILE=<your-sso-profile>

# 2. Verify identity
aws sts get-caller-identity        # should show account 235546316205

# 3. Tell Claude: "read PROGRESS.md and let's continue"
```

---

## ⚠️ Gotchas / Reminders

- `kubectl` works **only from the VDI** (private endpoint).
- Never commit `terra-key.pem` (it's gitignored — keep it that way).
- `terraform apply` was **NOT run yet** by Claude — user applies from VDI.
- State is in S3 + code in GitHub → project survives even if a session resets.
