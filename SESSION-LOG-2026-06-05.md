# 🗒️ Session Log — 2026-06-05 (covers 2026-06-04 → 06-05 work)

> **Purpose:** Narrative of this session so a future Claude session (after token/context
> loss) can sync. PROGRESS.md = source of truth; this = the story + gotchas.
> Previous session story is in SESSION-LOG-2026-06-04.md.

---

## ⚙️ UPDATE 2026-06-05 (latest) — REBUILT INFRA + got kubectl + Jenkins working

Rebuilt with `terraform apply` (cluster ACTIVE again), then fixed a chain of access/boot issues.
Each was diagnosed live and codified so a future recreate won't hit it.

**1. kubectl from VDI — network (SG) blocker.** `kubectl get nodes` → `dial tcp 10.174.62.154:443:
i/o timeout`. The VDI (`10.157.139.186`) sits OUTSIDE the cluster VPC (`10.174.62.0/24`) and reaches
in over the Transit Gateway, but neither cluster SG allowed 443 from it. Fix: added
`cluster_security_group_additional_rules` in `eks.tf` for `var.vdi_cidr`. Widened to the whole VDI
`/16` (`10.157.0.0/16`) — NOT a single host IP — so a new VDI IP / recreate stays reachable.

**2. kubectl from VDI — auth blocker.** Error then changed to "the server has asked for the client
to provide credentials" (= network fixed, authz now). `aws sts get-caller-identity` on the VDI
returns `assumed-role/ecsInstanceRole/<id>` — kubectl runs `aws eks get-token` with NO profile, so
it authenticates as the **VDI's EC2 instance role**, not the SSO role the cluster knew. Fix: added a
second EKS access entry `admin_vdi` (`var.vdi_instance_role_arn = arn:aws:iam::235546316205:role/
ecsInstanceRole`) with `AmazonEKSClusterAdminPolicy`. → nodes Ready.

**3. Jenkins wouldn't install/start on the Jenkins EC2** (`systemctl status jenkins` = not found).
cloud-init had finished (Java/Docker/Trivy/snaps installed) but Jenkins failed silently. Three
separate, stacked problems — all fixed live AND in `install_tools.sh`:
  - **Expired/rotated APT key + flat-repo quirk.** Repo gave `NO_PUBKEY 7198F4B714ABFC68`; the
    script's `jenkins.io-2023.key` expired 2026-03-26. Fetching the new key (HTTPS, since the box's
    TGW egress blocks the keyserver HKP port 11371) into a `signed-by` keyring STILL failed — apt
    doesn't reliably honour `signed-by` for Jenkins' flat (`binary/`) repo. **Resolution: install the
    `.deb` directly** (`jenkins_<latestCore>_all.deb`), no repo signing needed.
  - **Java 17 too old.** Jenkins LTS needs Java 21+ (`Supported Java versions are: [21, 25]`). Script
    installed `openjdk-17-jre` → now `openjdk-21-jre`.
  - **`/tmp` is `noexec`** (corporate hardening) → JNA `UnsatisfiedLinkError: failed to map segment
    from shared object` at boot. Fix: systemd drop-in sets `java.io.tmpdir=/var/lib/jenkins/tmp`
    (exec-allowed dir under Jenkins home; JNA follows `java.io.tmpdir`).
  - Bonus cleanups: Trivy repo line was duplicated 3× (`tee -a` → `tee`); dropped deprecated `apt-key`.
  → Jenkins now `active (running)`.

> ⚠️ `install_tools.sh` only runs on FIRST boot (cloud-init user-data). The fixes above make a fresh
> EC2 work, but the manual steps were needed on the already-running box. Image/Docker-Hub names in
> `Jenkinsfile` updated to `sayajirao/easyshop-app` + `sayajirao/easyshop-migration`.

---

## ⚠️ UPDATE 2026-06-05 (later session) — INFRA WAS DESTROYED
Resuming the next day, I verified the infra described below as "fully deployed" **no longer
exists.** Checks run: `aws eks list-clusters` → empty in every region; `describe-instances`
eu-central-1 → no Jenkins/Bastion (only unrelated projects' instances); S3 tfstate → empty
(`resources: []`, 794 B, serial 12). S3 version history shows a descending staircase
(127KB→69→60→34→22→0.8KB at 2026-06-04 ~20:10–20:21 UTC) = a **`terraform destroy`**, run ~1h
after the successful apply — almost certainly a deliberate overnight cost-saving teardown.
**Nothing is broken:** Terraform code + S3 backend are intact, so `terraform apply` rebuilds it
all. The "fully deployed" claims below were TRUE at the time of writing (2026-06-04 evening);
they are now historical. To resume the DEPLOY phase, first rebuild infra (PROGRESS.md STEP 0).

---

## TL;DR (read first) — as written 2026-06-04 evening (see UPDATE above: infra later destroyed)
- ✅ **Infrastructure FULLY DEPLOYED.** `terraform apply` succeeded. EKS cluster + nodes +
  Jenkins + Bastion are all live in eu-central-1.
- ✅ **OIDC/IRSA verified working** (was the big "UNVERIFIED" risk in PROGRESS.md — now resolved).
- ✅ Replicated + adapted `kubernetes/` (12 manifests) and `terraform/apps/` (Helm add-ons)
  into the repo, committed on branch `feat/k8s-and-addons`, merged to `main`.
- ✅ Replicated `README.md` from the reference repo (was a 1-line stub).
- ✅ Handled TWO secret leaks inherited from the reference repo (see below).
- ✅ Removed `Co-Authored-By: Claude` trailer from ALL commits (user does not want Claude
  shown as a GitHub contributor). Rewrote history on all branches + main, force-pushed.
- ⏭️ **NOT done yet:** applying `terraform/apps/`, deploying the app to the cluster.

---

## What we did, in order

### 1. (Quick detour) AWS SageMaker question — unrelated to this project
User asked how to set up SageMaker Studio in Frankfurt. Used AWS CLI (already configured,
SSO profile, account 235546316205) to inspect their existing us-east-1 SageMaker domains.
Gave region-replication steps. NOT part of the EasyShop project — ignore for sync.

### 2. Synced + found the git resume steps were already done
PROGRESS.md's old "EXACT RESUME STEPS" block was stale — the 6 app-code commits were
already made + pushed on `feat/app-source`. Committed the progress docs, opened/merged PRs.

### 3. Reviewed best practices (user asked "is everything correct?")
Flagged: empty README, stale terraform.tf comment, hardcoded account/VPC IDs, the auto-derived
git commit identity, minimal tagging, no CI. (Not all fixed — see PROGRESS.md "best practices".)

### 4. Compared reference repo vs ours; replicated missing pieces
Reference (`../tws-e-commerce-app_hackathon`) had these we lacked: `kubernetes/`,
`terraform/apps/` + `terraform/modules/`, `helm-values/`, `Jenkinsfile`/`JENKINS.md`,
`LICENSE`, `about.md`, full `README.md`.
- **Replicated README.md** (committed, kept reference content, to be tailored later).
- **Replicated + ADAPTED `kubernetes/` and `terraform/apps/` + `modules/`** on a new
  branch `feat/k8s-and-addons`. Adaptations (NOT blind copies — these are env-specific):
  - `kubernetes/04-configmap.yaml`: removed leaked NEXTAUTH_SECRET/JWT_SECRET (plaintext in ref).
  - `kubernetes/08-deployment` + `12-migration-job`: image set to TODO (build/push your own).
  - `kubernetes/10-ingress.yaml`: ACM cert ARN + domain flagged TODO (ref pointed at a
    stranger's account 876997124628 / us-east-1).
  - `terraform/apps/`: region ap-south-1 → eu-central-1; hardcoded OIDC URLs → `var.idp_provider_url`;
    ALB controller helm-values region + reused vpcId set; `terraform fmt` applied.
  - Added `terraform/apps/REPLICA-NOTES.md` documenting apply order + post-cluster TODOs.
  - Did NOT copy `Jenkinsfile`, `JENKINS.md`, `LICENSE`, `about.md`, top-level ELK `helm-values/`
    (still missing — see PROGRESS.md "not yet replicated").

### 5. terraform apply — the saga (all RESOLVED)
Ran from the user's machine. Hit a sequence of errors, each fixed:
1. **DNS dropout mid-apply** → `no such host` on S3/STS. Not a code issue. Recovered:
   `terraform force-unlock <id>`, deleted local-only `errored.tfstate` (had serial 0, only
   tls_private_key + local_file — NO aws resources), re-applied.
2. **SCP blocks public AMIs** → `UnauthorizedOperation ... explicit deny in service control
   policy p-epxkyj6z` on `ec2:RunInstances`. Verified via dry-run that BOTH public Ubuntu
   AND Amazon Linux AMIs are denied — it's a blanket deny on the user's role launching
   non-approved AMIs (EKS nodes launch fine because the EKS service-linked role is exempt).
   **Fix:** the org SHARES approved "golden" AMIs from account 717063266043
   (`AMI-RCP-CENTRALIZED-*`). Repointed `data.aws_ami.os_image` in `ec2.tf` to
   `AMI-RCP-CENTRALIZED-PB-UBUNTU-24.04-???20??` (the `???20??` excludes the DEEP-LEARNING
   variant that most_recent would otherwise pick). Dry-run confirmed it passes the SCP.
3. **Volume too small** → `InvalidBlockDeviceMapping: Volume of size 20GB is smaller than
   snapshot, expect >= 40GB`. The golden AMI ships a 40GB root snapshot. **Fix:** bumped
   `volume_size` 20 → 40 in both `ec2.tf` and `bastion_ec2.tf`.
4. **terra-key.pem read-only** → `local_file ... Access is denied`. Leftover from the crashed
   run made the key read-only. Fixed with `chmod u+w`.
→ Final apply SUCCEEDED. Both EC2 on `ami-031a0eb8a327b4f02` (RCP Ubuntu 24.04), t3.large.

### 6. Secret #2 — GitHub push protection
Pushing `feat/k8s-and-addons` was blocked: a **live Slack Incoming Webhook URL** in
`terraform/apps/helm-values/kube-prom-stack.yaml:548` (Alertmanager config, inherited from
the reference repo). Did NOT bypass. Redacted to `REPLACE-WITH-YOUR-OWN-WEBHOOK`, then
rewrote the offending commit (filter-branch / amend + cherry-pick) so the secret never
exists in history. Verified gone via `git log -S`. Branch then pushed clean.
> ⚠️ That webhook is the ORIGINAL author's live credential — still exists in the reference
> repo + upstream GitHub. Not ours to rotate. Just never copy that value again.

### 7. Removed Claude as GitHub contributor
User saw "claude" in the repo Contributors panel — caused by the `Co-Authored-By: Claude`
trailer on commit messages. Stripped it from ALL commits on `feat/app-source`,
`feat/k8s-and-addons`, AND `main` via `git filter-branch --msg-filter`. Verified trees are
byte-identical (only messages changed), only the user appears as author/committer.
User force-pushed all branches + main. Saved a memory note: NEVER add that trailer again.
> GitHub Contributors panel is CACHED — may take minutes-to-24h to drop Claude even after
> the clean force-push. The commits themselves are confirmed clean.

### 8. Gave the user a full beginner walkthrough of the whole project (they're new to DevOps).

---

## ⚠️ Gotchas / state to remember next session
1. **Infra is UP** — do not re-run apply expecting to create it; it exists in S3 state.
2. **SCP constraint:** this role canNOT launch public AMIs OR create some IAM resources.
   Use RCP golden AMIs (owner 717063266043). This is the same family as the existing
   "can't create VPC / can't create IAM roles" constraints.
3. **`terraform/apps/` IRSA risk:** `alb_controller.tf` + `ebs_csi_driver.tf` do
   `create_role = true` (IAM roles). May hit `iam:CreateRole` deny — if so, an admin must
   pre-create roles and switch to `create_role = false`. See REPLICA-NOTES.md.
4. **TODOs before deploying** (placeholders we left): OIDC id in `terraform/apps/variables.tf`;
   ACM cert ARN + domain in `kubernetes/10-ingress.yaml`; app + migration images in
   `08-deployment.yaml` / `12-migration-job.yaml`; Slack webhook in kube-prom-stack.yaml.
5. **NEVER add `Co-Authored-By: Claude`** to commits/PRs for this user.
6. **Local backup branches still exist** (`backup/main-pretrailer`, `backup/k8s-pretrailer`,
   `backup/app-source-pretrailer`, `backup/k8s-pre-scrub`) — they hold OLD history with the
   trailer + Slack secret. Do NOT push them. Safe to delete once user is satisfied:
   `git branch -D backup/main-pretrailer backup/app-source-pretrailer backup/k8s-pretrailer backup/k8s-pre-scrub`
7. `main` history has some DUPLICATE commits (PRs #3–#6 merged old + cleaned versions).
   Harmless, files correct, history a bit messy. Could tidy later if portfolio polish matters.

---

## ▶ Resume checklist (next session)
1. Read PROGRESS.md + this file + SESSION-LOG-2026-06-04.md.
2. Refresh SSO creds (see PROGRESS.md "If AWS SSO Credentials Expire").
3. From VDI/Bastion: `aws eks --region eu-central-1 update-kubeconfig --name tws-eks-cluster`
   then `kubectl get nodes`.
4. Apply `terraform/apps/` add-ons — fill OIDC id first (REPLICA-NOTES.md). Watch IRSA/IAM perms.
5. Build + push app image + migration image to a registry (Docker Hub or ECR).
6. Fill the `kubernetes/` TODOs (images, cert ARN, domain), then `kubectl apply -f kubernetes/`.
7. (Later) CI/CD, LICENSE/about.md, README tailoring, clean up backup branches.
