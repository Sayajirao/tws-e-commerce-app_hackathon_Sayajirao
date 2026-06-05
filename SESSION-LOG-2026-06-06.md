# 🗒️ Session Log — 2026-06-06

> **Purpose:** Narrative of this session so a future Claude session (after token/context
> loss) can sync. PROGRESS.md = source of truth; this = the story + gotchas.
> Prior sessions: SESSION-LOG-2026-06-05.md, SESSION-LOG-2026-06-04.md.

---

## TL;DR
Huge progress day. CI/CD went fully green, and the entire `terraform/apps/` add-on stack
(ArgoCD + ALB controller + EBS CSI + kube-prometheus-stack + ELK) is now INSTALLED on the cluster.
A long chain of env-specific blockers was diagnosed and fixed (and codified). **Remaining: deploy
the EasyShop app itself, then flip the endpoint back to private.**

---

## What we did, in order

### 1. Replicated remaining reference files (earlier)
Brought over `LICENSE`, `about.md`, `Jenkinsfile`, `JENKINS.md`, `terraform/README.md`, top-level
`helm-values/` (Slack webhook scrubbed). Committed in small parts (PRs / dev branch).

### 2. Jenkins CI/CD pipeline — got it fully GREEN
Job `easyshop`. Fixes:
- Branch `master`→`main` (repo has no master) — in Jenkinsfile env + the job + the shared lib.
- Docker Hub anonymous **pull rate limit** → `docker login` as jenkins user. ⚠️ creds live at
  `/home/jenkins/.docker/config.json` (build HOME=/home/jenkins, NOT /var/lib/jenkins). Manual —
  won't survive recreate. TODO: add a Docker-Hub-login STAGE to the Jenkinsfile.
- Shared lib `update_k8s_manifests.groovy`: migration image owner `laxg66`→`sayajirao`; push to
  `main`; URL-encode git password. ⚠️ old GitHub password `y@ji@1998` LEAKED in a build log →
  user ROTATED to a PAT.
- Result: build → test → Trivy → push BOTH images to Docker Hub → update kubernetes/ tags → push.

### 3. Understood terraform/apps wiring (teaching)
Confirmed: each add-on `.tf` calls the generic `../modules/alb_controller` module → one
`helm_release`. `templatefile()` injects `${...}` vars (e.g. replicaCount); `file()` for YAMLs with
no TF vars. helm-values files only run if a `.tf` references them. ELK files were UNREFERENCED.

### 4. Wrote ELK .tf files (elasticsearch.tf / filebeat.tf / kibana.tf)
Followed the existing pattern. KEY: used `file()` NOT `templatefile()` for filebeat — its
`${NODE_NAME}`/`${ELASTICSEARCH_*}` are RUNTIME container env-vars, not TF vars. Chart repo
`https://helm.elastic.co`, version 8.5.1, namespace `logging`, `create_namespace=true`,
filebeat/kibana `depends_on` elasticsearch.

### 5. terraform/apps apply — the blocker saga (ALL RESOLVED)
1. **Ran from laptop first → "cluster unreachable".** The apps stack uses helm/kubernetes
   providers → must reach the PRIVATE K8s API. Laptop can't (verified: endpoint publicAccess=false,
   laptop kubeconfig empty, TCP to endpoint failed). Root stack worked from laptop earlier only
   because it uses the `aws` provider (public endpoints). → Chose to TEMPORARILY enable public access.
2. **Enabled public endpoint** — added `var.cluster_public_access` (+ `cluster_public_access_cidrs`
   locked to operator IP `223.233.87.24/32`) in eks.tf/variables.tf. Applied root stack. Laptop
   kubectl then worked.
3. **IAM 409 EntityAlreadyExists** — the ALB policy + both IRSA roles already existed (created Jan
   2026). Switched alb_controller.tf/ebs_csi_driver.tf to REUSE via `data` sources (create blocks
   commented out, NOT deleted, so a fresh-account recreate just uncomments). This also PROVED the
   SSO role CAN create IAM (the long-feared deny never materialized).
4. **Stale OIDC trust** — reused roles trusted the wrong thing (ALB→`pods.eks.amazonaws.com`
   Pod-Identity; EBS→a dead **us-west-2** cluster). Fixed NON-destructively via
   `aws iam update-assume-role-policy` using `apps/trust-alb.json` + `apps/trust-ebs.json`
   (pre-filled for current OIDC `36BC109...` + correct SA subjects).
5. **Namespaces not found** (argocd, monitoring) — added `create_namespace=true` to those modules.
6. **EBS PVCs Pending → `InvalidVolume.NotFound`** — THE big one. Account has EBS
   encryption-by-default with a CUSTOMER-MANAGED KMS key; EBS CSI role had NO kms perms → volumes
   created then auto-deleted. Fix: new `AmazonEKS_EBS_CSI_KMS_Policy` (codified in ebs_csi_driver.tf
   + `var.ebs_kms_key_arn`). See memory [[ebs-csi-kms-encryption-gotcha]]. PVC then bound.
7. **Node too small** — bumped `t3.large`→`t3.xlarge` + desired_size 1→2 (ELK+Prom+app need RAM).
8. **Kibana retries left orphans** ("name still in use" / "configmap already exists") — cleared with
   `kubectl delete secret -l owner=helm,name=kibana` + leftover objects + `terraform state rm
   module.kibana.helm_release.this[0]` between attempts.
→ Final `terraform apply` SUCCEEDED. ArgoCD, ALB controller, EBS CSI, kube-prom-stack, ELK installed.

---

## ⚠️ State to remember next session
1. **ENDPOINT IS PUBLIC right now** (locked to `223.233.87.24/32`). `var.cluster_public_access`
   default is currently `true` in variables.tf (it was toggled). MUST flip back to false + re-apply
   ROOT stack when deploying is done. If operator IP changed, update `cluster_public_access_cidrs`.
2. **UNCOMMITTED on branch `dev`** (commit tomorrow): PROGRESS.md, terraform/eks.tf,
   terraform/variables.tf, terraform/apps/{argocd,ebs_csi_driver,kube-prom-stack,variables}.tf.
   (The ELK .tf + trust-*.json were already committed in 899196d.)
3. **Apps stack uses LOCAL state** (terraform/apps/terraform.tfstate, gitignored) — lives on the
   LAPTOP. Must run apps applies from the same machine, or migrate to S3.
4. **Jenkins docker login is manual** at /home/jenkins/.docker/config.json — won't survive recreate.
5. NOT verified yet: that all add-on pods reached Running + all PVCs Bound (ES/Prom/Grafana). Run
   `kubectl get pods -A` + `kubectl get pvc -A` next session.

---

## ▶ Resume checklist (next session)
1. Read PROGRESS.md + this file + the memory notes.
2. Confirm endpoint still public OR re-enable (var.cluster_public_access=true, apply root) so laptop
   kubectl works; refresh SSO creds.
3. Verify add-ons healthy: `kubectl get pods -A`, `kubectl get pvc -A` (all Running/Bound).
4. **Deploy the EasyShop app** — the real remaining work. Either:
   - `kubectl apply -f kubernetes/` directly (fill TODOs: ACM cert ARN + domain in 10-ingress.yaml,
     check 05-secrets.yaml; images already set by the Jenkins pipeline), OR
   - Wire an ArgoCD Application pointing at `kubernetes/` on `main` (GitOps payoff).
5. Verify app: pods Ready, ingress gets an ALB DNS, site loads over HTTPS.
6. Commit the uncommitted dev changes (see above).
7. ⚠️ Flip endpoint back to PRIVATE (cluster_public_access=false, apply root) when done.
