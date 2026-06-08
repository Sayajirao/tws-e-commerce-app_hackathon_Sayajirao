# 📋 Project Progress — EasyShop on EKS

> **Purpose:** Progress tracker + context file. At the start of any session, read this
> file to get fully caught up. At the end of a session, update it.

---

## 🎯 Goal
Replicate the **EasyShop** full-stack e-commerce app (Next.js + MongoDB) and deploy it
on **AWS EKS**, building the DevOps stack step by step as a portfolio project.
Source reference repo: `../tws-e-commerce-app_hackathon` (the original clone).

---

## 🟢 CURRENT STATUS — DEPLOYED & LIVE on a PERSONAL AWS account (2026-06-08)

After proving everything worked on the Roche corporate account (but being blocked from
public exposure by corporate controls), the project was redeployed on a **fresh personal
account** where there are no such limits. **It is fully live and verified.**

| Item | Value |
|------|-------|
| AWS Account | `115019372174` (personal) |
| Region | `ap-south-1` |
| Auth | IAM user `sayajiraw_iam_user`, profile **`personal`** in `~/.aws/credentials` |
| Cluster | `tws-eks-cluster` (k8s v1.31), **PUBLIC endpoint** locked to operator IP |
| Nodes | 2× `t3.xlarge` SPOT |
| VPC | created by Terraform `module.vpc` (`vpc-05221f64adbf63c39`), public+private subnets, NAT/IGW |
| State | root stack → S3 bucket `easyshop-tfstate-sayajirao`; **apps stack → LOCAL** (`terraform/apps/terraform.tfstate`) |
| Branch | `feat/personal-account` (changes uncommitted — user commits manually) |
| GitHub repo | `github.com/Sayajirao/tws-e-commerce-app_hackathon_Sayajirao` |

**What's running (all verified):** VPC + EKS + Jenkins + Bastion; add-ons (Helm) — ALB
controller, EBS CSI, ArgoCD, kube-prometheus-stack, ELK; EasyShop app (2 replicas) +
mongodb-0 (PVC bound), **516 products migrated**.

**ONE shared ALB** `k8s-easyshop-79768b673f-...ap-south-1.elb.amazonaws.com` serves all
five by path — every one returns HTTP 200:
| Path | Service | Login |
|------|---------|-------|
| `/` | EasyShop storefront | — |
| `/grafana` | Grafana | admin / `prom-operator` |
| `/argocd` | ArgoCD | admin / `argocd-initial-admin-secret` |
| `/kibana` | Kibana | (no auth) |
| `/prometheus` | Prometheus | (no auth) |

Full runbook: **`DEPLOY-PERSONAL-ACCOUNT.md`**.

---

## 🔜 What's left

- [ ] **Commit the work** on `feat/personal-account` (user does this manually — small
      conventional commits, NO Claude trailer). Uncommitted: `terraform/**` refactor, all
      `terraform/apps/helm-values/*` dashboard + shared-ALB fixes, `kubernetes/10-ingress.yaml`
      (`group.order`), `DEPLOY-PERSONAL-ACCOUNT.md`, this file, deleted Roche leftovers + session logs.
      `05-secrets.yaml` is placeholders in git (real secrets live-only) — verified safe to commit.
- [ ] **💰 TEAR DOWN when done demoing** (~$0.50–1/hr: 2 nodes + NAT + 2 EC2 + EBS + ALB):
      `kubectl delete -f kubernetes/` → `terraform destroy` in `apps/` → `terraform destroy` in root.
- [ ] *(optional)* HTTPS: own a domain, ACM cert in ap-south-1, add cert ARN + HTTPS listener to the
      app + dashboard ingresses (switch the whole shared `group.name: easyshop` to HTTPS together).
- [ ] *(optional)* Lock Prometheus/Kibana down (they're public + no-auth on the shared ALB) — separate
      IP-restricted ALB or port-forward-only.

---

## 🔁 Daily startup (personal account)

```powershell
# PowerShell — set the profile for the session (NOT the bash AWS_PROFILE=x prefix)
$env:AWS_PROFILE = "personal"
aws sts get-caller-identity                  # must show 115019372174
aws eks --region ap-south-1 update-kubeconfig --name tws-eks-cluster
kubectl get nodes                            # both Ready
# If kubectl/EKS API times out: your IP changed — update cluster_public_access_cidrs in
# terraform/variables.tf (curl checkip.amazonaws.com) and `terraform apply` the root stack.
```

---

## 🧠 Hard-won lessons (the "why", so a redeploy doesn't rediscover them)

**Add-ons are Helm charts deployed by Terraform** (`helm_release`), never installed on the EC2s.
Edit `terraform/apps/helm-values/*.yaml` then `terraform apply` — don't `helm install` by hand.

**ALB controller values must match THIS cluster** (`alb_controller-1.13.3.yaml`): `region:
ap-south-1`, `vpcId: <the created VPC>`, `clusterName: tws-eks-cluster`. Wrong values CrashLoop
the controller or make it reject the subnets as "tagged for other clusters".

**Shared-ALB dashboards (the gotcha chain — each blocked the whole ALB group):**
1. ArgoCD chart defaults to a **GRPC** target group → can't attach to HTTP listener → poisons the
   group. Fix: `server.ingress.aws.backendProtocolVersion: HTTP1`.
2. ArgoCD `global.domain` default adds a host-header condition that never matches the ALB DNS name.
   Fix: `global.domain: ""`.
3. Each app needs **subpath config** (root_url / basehref / basePath / routePrefix) or it 404s on assets.
4. Each ingress needs a **health-check path on its subpath** (default `/` → unhealthy → ALB 404).
5. **#1 cause of 404:** the app's `/*` catch-all must sort LAST — `group.order` app `100`,
   dashboards `10`–`13`. (A 404 with `X-Powered-By: Next.js` = the path hit the app, fix order.)
6. Kibana chart 8.5.1 probe uses `healthCheckPath` verbatim → set `/kibana/login`. And every apply
   re-runs a token hook that **409s** on the existing `kibana-kibana-es-token` secret → delete that
   secret + the `pre-install-kibana-kibana` job/cm/sa/role/rolebinding, re-apply, then
   `rollout restart deployment kibana-kibana`.

---

## 📜 History (Roche account — done, now superseded)

The project was first built on the Roche corporate account (`235546316205`, eu-central-1) and
proven fully working (GET / → 200, /api/products → 516 products), but every public-exposure path
was blocked. The pivot to the personal account (2026-06-07) flipped these workarounds back to the
"proper" design. Roche-era specifics (reused VPC/IAM via data sources, private-only endpoint + VDI
access, EBS customer-KMS policy, Cloudflare-only NACL, hardened-AMI/Jenkins boot fixes, the
`Co-Authored-By: Claude` history scrub) are captured in Claude memory ([[easyshop-eks-project]])
rather than here. Key carry-overs kept regardless of account: MongoDB
`public.ecr.aws/docker/library/mongo:8.0` (Docker Hub rate-limit dodge) and `HOSTNAME=0.0.0.0` on
the app deployment (Next standalone correctness). CI/CD: Jenkins pipeline builds + pushes
`sayajirao/easyshop-app` + `sayajirao/easyshop-migration` to Docker Hub.

---

## ⚠️ Standing reminders
- **PowerShell**, profile `personal`. Don't overwrite `[default]` in `~/.aws/credentials`.
- Never commit `terraform/terra-key.pem` (gitignored) or real secrets.
- **NEVER add `Co-Authored-By: Claude`** (or any AI trailer) to commits/PRs — portfolio repo.
- State (S3 root + local apps) + code in GitHub → project survives a session reset.
