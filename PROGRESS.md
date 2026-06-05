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
- [x] **App-source PRs merged to `main`** (README also replicated from reference repo).
- [x] **INFRASTRUCTURE WAS DEPLOYED, THEN DESTROYED** (`terraform apply` succeeded 2026-06-04,
  then `terraform destroy` ~1h later — likely an overnight cost-saving teardown):
  - ⚠️ **AS OF 2026-06-05, NO INFRA EXISTS.** Verified: no EKS cluster `tws-eks-cluster` in any
    region; no Jenkins/Bastion EC2 (running instances in eu-central-1 belong to other projects).
    S3 tfstate is back to empty (`resources: []`, 794 bytes, serial 12). The descending S3
    state-version staircase (127KB→…→794B around 2026-06-04 20:10–20:21 UTC) confirms a destroy.
  - ✅ The apply itself DID succeed earlier: EKS cluster `tws-eks-cluster` (v1.31) + managed node
    group (1× t3.large, SPOT) + **OIDC/IRSA VERIFIED working** (the big UNVERIFIED risk — resolved)
    + Jenkins + Bastion EC2 on the RCP golden AMI all came up. Terraform CODE + S3 backend are
    intact, so a single `terraform apply` rebuilds everything (idempotent by design).
  - **SCP gotcha solved:** org SCP `p-epxkyj6z` denies the role launching public AMIs; switched
    `data.aws_ami` to org-shared `AMI-RCP-CENTRALIZED-PB-UBUNTU-24.04-*` (owner 717063266043),
    bumped EC2 root volume 20→40 GB (golden AMI ships a 40 GB snapshot).
- [x] **Replicated + ADAPTED `kubernetes/` (12 manifests) + `terraform/apps/` + `modules/`**
  on branch `feat/k8s-and-addons`, merged to `main`. Env-specific adaptations made, NOT blind
  copies — placeholders left as TODOs (see Next Steps). Added `terraform/apps/REPLICA-NOTES.md`.
- [x] **Fixed 2 inherited secret leaks:** removed plaintext secrets from `04-configmap.yaml`;
  redacted a live Slack webhook from `kube-prom-stack.yaml` (rewrote history so it never existed).
- [x] **Removed `Co-Authored-By: Claude` trailer** from all commits + `main` (force-pushed).
  ⚠️ NEVER re-add it. Local `backup/*` branches hold the old history — don't push; delete when ready.

- [x] **INFRA REBUILT + cluster reachable from VDI** (2026-06-05, later session). After the
  overnight destroy, re-ran `terraform apply` → cluster ACTIVE again. Fixed TWO access blockers,
  both now codified in Terraform (survive future recreates):
  - **Network:** VDI (`10.157.x.x`, reaches the VPC over the TGW) couldn't hit the private API
    endpoint — cluster SG had no 443 ingress from it → `i/o timeout`. Added
    `cluster_security_group_additional_rules` for `var.vdi_cidr` (`10.157.0.0/16`).
  - **Auth:** kubectl on the VDI authenticates as the VDI's EC2 instance role `ecsInstanceRole`
    (not the SSO role) → API said "asked for credentials". Added a second access entry
    `admin_vdi` (`var.vdi_instance_role_arn`) granting it cluster-admin. → `kubectl get nodes` works.
- [x] **Jenkins installed + running on the Jenkins EC2** (2026-06-05). Boot user-data had failed;
  fixed live AND in `install_tools.sh` (3 distinct issues, all env-specific to this hardened image):
  - Jenkins LTS needs **Java 21** (script installed 17 → service refused to start). → `openjdk-21-jre`.
  - apt rejected the Jenkins flat repo (`NO_PUBKEY 7198F4B714ABFC68`) even with the correct key;
    apt doesn't honour `signed-by` for that repo layout. → install the **.deb directly**.
  - `/tmp` is mounted **`noexec`** → JNA `UnsatisfiedLinkError` at boot. → systemd drop-in points
    `java.io.tmpdir` at `/var/lib/jenkins/tmp` (exec-allowed).
  - Also de-duplicated the Trivy repo line (`tee -a` → `tee`) and dropped deprecated `apt-key`.

> See **SESSION-LOG-2026-06-05.md** for the full blow-by-blow of the apply saga + secret scrubs.

---

## 🔜 Next Steps

> **STATUS (updated 2026-06-05, later session):** ✅ Infra REBUILT, `kubectl get nodes` works from
> the VDI, and Jenkins is running. SG + access-entry fixes are codified so a future recreate stays
> reachable. Remaining work is the rest of the **DEPLOY phase** (add-ons → images → app). All
> commands run from the **VDI/Bastion** (private cluster endpoint); refresh SSO creds first.

### ▶ DEPLOY PHASE (in this order)
1. [x] **Connect to the cluster** (from VDI/Bastion) — DONE, node is Ready:
   ```bash
   aws eks --region eu-central-1 update-kubeconfig --name tws-eks-cluster
   kubectl get nodes        # confirm the node is Ready
   ```
2. [x] **`terraform/apps/` add-ons APPLIED** (2026-06-06) — ArgoCD, ALB controller, EBS CSI,
   kube-prometheus-stack, AND the ELK stack (Elasticsearch/Filebeat/Kibana) all installed.
   Applied from the LAPTOP (not VDI) by temporarily enabling the public endpoint. Hard-won fixes:
   - **IAM already existed** (from a Jan run) → 409 `EntityAlreadyExists`. Switched
     `alb_controller.tf`/`ebs_csi_driver.tf` to REUSE via `data` sources (create blocks commented,
     not deleted). NOTE: this proved the SSO role CAN create IAM (the feared deny never happened).
   - **Stale OIDC trust** on the reused roles (ALB→Pod-Identity, EBS→dead us-west-2 cluster). Fixed
     non-destructively with `aws iam update-assume-role-policy` (trust JSONs: `apps/trust-*.json`).
   - **EBS volumes wouldn't provision** (`InvalidVolume.NotFound`): account has EBS
     encryption-by-default with a CUSTOMER-MANAGED KMS key, and the EBS CSI role had NO `kms:`
     perms → volumes created then auto-deleted. Fixed: new `AmazonEKS_EBS_CSI_KMS_Policy` (codified
     in `ebs_csi_driver.tf` + `var.ebs_kms_key_arn`). PVCs then bound → ES started → Kibana succeeded.
   - **Namespaces**: added `create_namespace = true` to argocd + kube-prom-stack modules.
   - **Node scale**: bumped node group `t3.large`→`t3.xlarge`, desired_size 1→2 (ELK+Prom+app needs RAM).
   - Helm release retries left orphans (configmaps/jobs/release-secret) → cleared with `kubectl delete`
     + `terraform state rm module.kibana...` between attempts.
   ⚠️ ENDPOINT IS CURRENTLY PUBLIC (locked to operator IP `223.233.87.24/32`). Flip
   `cluster_public_access` back to false + re-apply ROOT stack when done deploying.
3. [ ] **Build + push images** — ✅ ALREADY DONE via the Jenkins CI pipeline (`sayajirao/easyshop-app`
   + `sayajirao/easyshop-migration` on Docker Hub). Pipeline also auto-updates `kubernetes/` image tags.
4. [ ] **Fill the `kubernetes/` TODOs**, then deploy:
   - `08-easyshop-deployment.yaml` + `12-migration-job.yaml` → your image names
   - `10-ingress.yaml` → your ACM cert ARN (eu-central-1) + your domain
   - then: `kubectl apply -f kubernetes/`
5. [ ] **Verify** the app: pods Ready, ingress gets an ALB address, site loads over HTTPS.

### ▶ THEN — polish / optional
- [x] **CI/CD pipeline GREEN end-to-end** (2026-06-06). Jenkins job `easyshop` runs: build → unit
      tests → Trivy scan → push BOTH images to Docker Hub (`sayajirao/easyshop-app` +
      `sayajirao/easyshop-migration`) → update `kubernetes/` image tags + push back to `main`.
      Fixes applied to get here:
      - Jenkins job + `Jenkinsfile` `GIT_BRANCH`: `master` → `main` (repo has no master branch).
      - Docker Hub anonymous pull-rate-limit → `docker login` as jenkins user. ⚠️ Done MANUALLY at
        `/home/jenkins/.docker/config.json` (NOT `/var/lib/jenkins` — builds run with HOME=/home/jenkins);
        won't survive a Jenkins/EC2 recreate. TODO: add a Docker-Hub-login stage to the Jenkinsfile.
      - Shared lib `update_k8s_manifests.groovy`: migration image owner `laxg66` → `sayajirao`;
        push target → `main`; URL-encode git password (a literal `@` in the old password broke the
        push URL). ⚠️ Old GitHub password `y@ji@1998` LEAKED in a build log — ROTATED to a PAT.
- [x] Replicated still-missing reference files: `Jenkinsfile`, `JENKINS.md`, `LICENSE`,
      `about.md`, top-level ELK `helm-values/`, `terraform/README.md` (merged via PRs #7/#8).
      `Jenkinsfile` image names updated to `sayajirao/easyshop-app` + `sayajirao/easyshop-migration`.
- [ ] Tailor README to eu-central-1 + add architecture diagram. Fix Slack webhook placeholder.
- [ ] Clean up: delete local `backup/*` branches; optionally tidy duplicate commits on `main`.

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
- ⚠️ **Infra was DESTROYED 2026-06-04 (~20:21 UTC)** — apply succeeded earlier that day, then a
  `terraform destroy` tore it all down (likely overnight cost-saving). As of 2026-06-05 NO infra
  exists (verified: no cluster, no EC2, empty S3 state). Must `terraform apply` again to rebuild
  (see Next Steps STEP 0). State + code intact, so apply is idempotent. User runs apply/kubectl from VDI.
- **SCP `p-epxkyj6z`**: this role canNOT launch public AMIs (use RCP golden AMIs, owner
  717063266043) and may not create some IAM resources. Same family as the no-VPC/no-IAM-role limits.
- **NEVER add `Co-Authored-By: Claude`** (or any AI trailer) to commits/PRs — portfolio repo.
- State is in S3 + code in GitHub → project survives even if a session resets.
