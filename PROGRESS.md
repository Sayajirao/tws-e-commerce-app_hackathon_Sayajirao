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
- [x] **PR #1 merged** → all `terraform/` code is now on `main`. (Two `docs: progress
      tracker` commits stayed on `feat/terraform-eks` and never reached `main`.)
- [x] **Replicated the full application code** into this repo (copied from the
      reference repo, then verified byte-identical via `diff -rq`):
  - `src/` (163 files), `public/` (616 files), `.db/` (2 seed files),
    `scripts/` (migration: migrate-data.ts, Dockerfile.migration, tsconfig.json)
  - Config: package.json, package-lock.json, yarn.lock, tsconfig.json,
    next.config.js/.cjs, tailwind.config.ts, postcss.config.js, components.json,
    .eslintrc.json, ecosystem.config.cjs
  - Docker: Dockerfile (prod), Dockerfile.dev, docker-compose.yml, .dockerignore
  - **Secret-safe:** did NOT copy the reference's real `.env` (it had live secrets).
    Created `.env.example` with placeholders + hardened `.gitignore` (node_modules,
    .next, .env*, logs). Verified no secret values leaked anywhere in the repo.
  - **Skipped (your call later):** `LICENSE`, `about.md` (optional portfolio docs).

---

## 🔜 Next Steps

> **STATUS (updated 2026-06-04, later):** App-source work is essentially DONE.
> All 6 app-code commits (`e82387c` → `53d8859`) are on `feat/app-source` and
> **pushed to origin**. PR #2 (terraform) is merged → `main`. The old "EXACT RESUME
> STEPS" block has been executed and removed. **Only remaining app step: open & merge
> the `feat/app-source` → `main` PR.** (`gh` CLI not installed locally → use browser.)

### ▶ MERGE THE APP-SOURCE PR (do this first next session)
```bash
# The 6 app commits + docs are pushed. Just open the PR in a browser and merge:
#   https://github.com/Sayajirao/tws-e-commerce-app_hackathon_Sayajirao/compare/main...feat/app-source
```
- [ ] Open PR `feat/app-source` → `main`, review, merge.
- [ ] (Optional) decide on `LICENSE` / `about.md` portfolio docs.

### ▶ THEN — the DevOps work (after `terraform apply`, planned after 7 PM)
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

## 🔐 If AWS SSO Credentials Expire (READ THIS FIRST when commands fail)

**Symptom:** AWS/Terraform/kubectl commands fail with errors like
`ExpiredToken`, `The security token included in the request is expired`,
`Unable to locate credentials`, or `Error when retrieving token from sso`.

**My SSO profile name:** `common-usecase-pwrusr-235546316205`
**SSO portal:** https://d-996713358d.awsapps.com/start/#

**Fix — run these (takes ~20 seconds):**
```bash
# 1. Re-login via SSO (opens browser → approve the request)
aws sso login --profile common-usecase-pwrusr-235546316205

# 2. Make every tool use this profile for the session
export AWS_PROFILE=common-usecase-pwrusr-235546316205

# 3. Confirm it worked — should print account 235546316205
aws sts get-caller-identity
```

**Notes:**
- If the browser doesn't open automatically, copy the URL/code it prints and open manually.
- To avoid running `export` every time, add this line to `~/.bashrc`:
  `export AWS_PROFILE=common-usecase-pwrusr-235546316205`
- Terraform & kubectl need NO changes — they read `AWS_PROFILE` automatically.
- If `aws sso login` itself fails, the profile may be gone — re-create with
  `aws configure sso` (start URL + region `eu-central-1` + account + role above).

### ⚠️ If the token expires in the MIDDLE of a long command (IMPORTANT)

`terraform apply` for EKS takes ~15–20 min — long enough that the token can
expire DURING it, causing the apply to fail partway (e.g. `ExpiredToken`).
**This is recoverable and safe — do NOT panic, do NOT delete anything.**

Why it's safe: Terraform state lives in S3 (`k8s-buckettttt`) and Terraform is
idempotent. A half-finished apply just means some resources aren't created yet.

**Recovery:**
```bash
# 1. Re-login
aws sso login --profile common-usecase-pwrusr-235546316205
export AWS_PROFILE=common-usecase-pwrusr-235546316205

# 2. Simply run apply AGAIN — it reads S3 state and finishes the rest.
#    It will NOT duplicate anything already created.
terraform plan      # optional: shows only what's left to create
terraform apply
```

- If a previous run left a **state lock** (error: "Error acquiring the state lock"),
  it's because the killed process didn't release it. Unlock with the LockID shown:
  `terraform force-unlock <LOCK_ID>`  (only do this if you're sure no apply is running).
- Same idea for **kubectl**: if a token expires mid-session, just re-login — the
  kubeconfig auto-fetches a fresh token on the next command. No reconfig needed.

---

## 🛠️ Daily Startup Routine

```bash
# 1. Refresh AWS SSO creds (see section above if anything errors)
aws sso login --profile common-usecase-pwrusr-235546316205
export AWS_PROFILE=common-usecase-pwrusr-235546316205

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
