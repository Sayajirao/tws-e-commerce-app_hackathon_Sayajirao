# 🚀 Deploy EasyShop on EKS — Personal AWS Account (start to end)

> Branch: `feat/personal-account`. Region: **ap-south-1**. This rebuilds everything
> from scratch (own VPC + IAM + EKS + add-ons + app) — none of the Roche-account
> constraints (reuse-only VPC/IAM, private endpoint, Cloudflare NACL) apply here.

---

## 0. Prerequisites (one-time)

```bash
# Configure your PERSONAL account credentials (admin/IAM user with broad rights).
aws configure                       # or: aws configure sso
aws sts get-caller-identity         # confirm it's YOUR account, not Roche (235546316205)

# Tools: terraform >= 1.3, kubectl, helm, awscli v2, docker (for any image work).
```

**Set your operator IP** (the EKS public endpoint is locked to it):
```bash
curl -s checkip.amazonaws.com       # note your public IP
```
If it isn't `223.233.83.25`, edit `terraform/variables.tf` →
`cluster_public_access_cidrs` default to `["<YOUR_IP>/32"]`.

**Create the Terraform state bucket** and wire it in:
```bash
aws s3 mb s3://<YOUR_TFSTATE_BUCKET> --region ap-south-1
```
Then edit `terraform/terraform.tf` → replace `<YOUR_TFSTATE_BUCKET>` with that name.

---

## 1. Root stack — VPC + EKS + Jenkins/Bastion

```bash
cd terraform
terraform init          # initializes the S3 backend
terraform plan          # review: VPC, EKS cluster, 2x t3.xlarge nodes, Jenkins+Bastion EIPs
terraform apply         # ~15-20 min for EKS
```

Connect kubectl:
```bash
aws eks --region ap-south-1 update-kubeconfig --name tws-eks-cluster
kubectl get nodes       # both nodes Ready
```

Outputs you'll get: `jenkins_url` (http://<eip>:8080), `bastion_public_ip`,
`update_kubeconfig_command`, `eks_cluster_endpoint`.

---

## 2. Apps stack — add-ons via HELM CHARTS (ALB controller, EBS CSI, ArgoCD, Prometheus, ELK)

> **How the add-ons are deployed: Helm charts, not EC2.** Every add-on is a public Helm
> chart installed by Terraform's `helm_release` resource (wrapped in `modules/alb_controller`).
> You do **not** install anything on the Jenkins/Bastion EC2s — those are just a CI host + an
> SSH jump box. The control flow is: `terraform/apps/*.tf` → `helm_release` → chart pulled from
> its repo → rendered with the matching file in `terraform/apps/helm-values/` → applied to the
> cluster via your local `~/.kube/config`. To change an add-on, edit its `helm-values/*.yaml`
> and re-run `terraform apply` (NOT `helm install` by hand — Terraform owns the releases).
>
> | Add-on | `.tf` file | chart repo | values file |
> |---|---|---|---|
> | AWS Load Balancer Controller | `alb_controller.tf` | aws.github.io/eks-charts | `alb_controller-1.13.3.yaml` |
> | EBS CSI driver | `ebs_csi_driver.tf` | kubernetes-sigs…/aws-ebs-csi-driver | `ebs-csi-driver-2.45.1.yaml` |
> | ArgoCD | `argocd.tf` | argoproj.github.io/argo-helm | `argocd-values.yaml` |
> | kube-prometheus-stack (Prometheus+Grafana) | `kube-prom-stack.tf` | prometheus-community | `kube-prom-stack.yaml` |
> | Elasticsearch / Kibana / Filebeat (ELK) | `elasticsearch.tf` / `kibana.tf` / `filebeat.tf` | helm.elastic.co | `elasticsearch.yaml` / `kibana.yaml` / `filebeat.yaml` |
>
> The chart `helm` + `kubernetes` providers point at `~/.kube/config`, so **kubectl must already
> work** (the §1 `update-kubeconfig`) before this stack applies, or the helm releases can't reach
> the cluster. Requires the `helm` CLI on PATH only for occasional manual debugging
> (`winget install Helm.Helm`); the apply itself uses the provider's bundled helm.

**First** grab the cluster's OIDC URL (the IRSA roles need it) and set it:
```bash
aws eks describe-cluster --name tws-eks-cluster --region ap-south-1 \
  --query "cluster.identity.oidc.issuer" --output text
# -> https://oidc.eks.ap-south-1.amazonaws.com/id/XXXXXXXX
```
Edit `terraform/apps/variables.tf` → `idp_provider_url` default = that value
**without** the leading `https://`.

Then apply (uses your local `~/.kube/config`, so kubectl must already work):
```bash
cd apps
terraform init
terraform apply
```

Verify add-ons:
```bash
kubectl get pods -A      # ALB controller, ebs-csi, argocd, monitoring, logging all Running
kubectl get sc           # ebs-storage-class (default)
```

> Note: the ArgoCD / Grafana / Prometheus / Kibana **ingresses are ENABLED and share the
> app's ALB** by path (`/grafana`, `/argocd`, `/kibana`, `/prometheus`) — see §5. (Port-forward
> still works as a fallback if you'd rather not expose them.)

---

## 3. Deploy the EasyShop app

Images are already on Docker Hub (`sayajirao/easyshop-app:10`,
`sayajirao/easyshop-migration:10`). Just apply the manifests:
```bash
cd ../..                 # repo root
kubectl apply -f kubernetes/
```

Watch it come up:
```bash
kubectl -n easyshop get pods -w
# mongodb-0 Running, easyshop-* Running (2), db-migration Completed
kubectl -n easyshop logs job/db-migration | tail   # "Migrated 516 products"
```

If the migration Job ran before MongoDB was ready (ECONNREFUSED), re-run it:
```bash
kubectl -n easyshop delete job db-migration
kubectl apply -f kubernetes/12-migration-job.yaml
```

---

## 4. Verify the app over the internet (this WILL work here)

```bash
kubectl -n easyshop get ingress      # wait for an ADDRESS (k8s-easyshop-...elb.amazonaws.com)
ALB=$(kubectl -n easyshop get ingress easyshop-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -sI http://$ALB/                 # HTTP 200
curl -s  http://$ALB/api/products | head -c 300   # product JSON from MongoDB
```
Open `http://$ALB/` in a browser — the storefront loads (no Cloudflare/NACL block here).

---

## 5. Access the dashboards — SHARED ALB by path (preferred)

All four dashboards ride the **same ALB as the app**, routed by URL path. Get the ALB host:
```bash
ALB=$(kubectl -n easyshop get ingress easyshop-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://$ALB/"            # storefront
echo "http://$ALB/grafana"     # Grafana   (user: admin)
echo "http://$ALB/argocd"      # ArgoCD    (user: admin)
echo "http://$ALB/kibana"      # Kibana    (no auth)
echo "http://$ALB/prometheus"  # Prometheus (no auth)
```
Passwords:
```bash
# ArgoCD admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
# Grafana admin  (default below; overridable in kube-prom-stack.yaml)
echo "prom-operator"
```

**How the shared-ALB routing is wired (and the gotchas that WILL bite on a fresh deploy):**
This is the hard-won part — all configured in the `helm-values/*.yaml`. If a dashboard 404s or a
target is unhealthy, it's almost always one of these:
- **Same ALB:** every dashboard ingress + the app ingress use
  `alb.ingress.kubernetes.io/group.name: easyshop`. Same group name → one ALB, merged by path.
- **Rule priority (the #1 cause of 404):** the app's `/*` catch-all must sort LAST or it shadows
  the dashboards. Set `group.order` — app `'100'`, dashboards `'10'..'13'`. A 404 whose response
  header shows `X-Powered-By: Next.js` means the path hit the app, not the dashboard → fix order.
- **Subpath config** (or the app 404s on its own assets): Grafana `grafana.ini.server.root_url`
  +`serve_from_sub_path: true`; ArgoCD `server.basehref`+`server.rootpath`=`/argocd`; Kibana
  `server.basePath: /kibana`+`rewriteBasePath: true`; Prometheus `routePrefix`+`externalUrl`=`/prometheus`.
- **Health-check path** must target the subpath (default `/` → unhealthy → ALB 404):
  `alb.ingress.kubernetes.io/healthcheck-path` = grafana `/grafana/api/health`, prometheus
  `/prometheus/-/ready`, kibana `/kibana/login`, argocd `/argocd` (+ `success-codes: 200,301`).
- **ArgoCD only:** `server.ingress.aws.backendProtocolVersion: HTTP1` (the chart defaults to GRPC,
  which can't attach to an HTTP listener and breaks the *whole* ALB group) and `global.domain: ""`
  (else it adds a host-header condition that never matches the ALB DNS name).
- **Kibana only:** chart 8.5.1 readiness probe uses `healthCheckPath` verbatim → set it to
  `/kibana/login`. And every apply re-runs a token hook that 409s on the existing
  `kibana-kibana-es-token` secret — if Kibana hangs/`503`s, delete that secret + the
  `pre-install-kibana-kibana` job/configmap/sa/role/rolebinding, re-apply, then
  `kubectl -n logging rollout restart deployment kibana-kibana`.

> ⚠️ Prometheus + Kibana have **no auth** and on a shared ALB group `inbound-cidrs` is group-wide
> (would lock the app too), so they're publicly reachable. Fine for a short demo; for anything
> longer, put them on a separate IP-locked ALB or keep them port-forward-only.

### Fallback: port-forward (no public exposure)
```bash
kubectl -n argocd      port-forward svc/my-argo-cd-argocd-server 8080:443   # https://localhost:8080
kubectl -n monitoring  port-forward svc/my-kube-prometheus-stack-grafana 3001:80      # http://localhost:3001
kubectl -n monitoring  port-forward svc/my-kube-prometheus-stack-prometheus 9090:9090 # http://localhost:9090
kubectl -n logging     port-forward svc/kibana-kibana 5601:5601                        # http://localhost:5601
```

---

## 6. Teardown (to stop costs)

```bash
kubectl delete -f kubernetes/          # app first (releases the ALB)
cd terraform/apps && terraform destroy # add-ons + IRSA roles
cd ..            && terraform destroy   # cluster + VPC + EC2
```

---

## Notes / leftovers
- Add-ons are **Helm charts deployed by Terraform** (`helm_release`), never installed on the
  EC2s — see the table in §2. Edit `terraform/apps/helm-values/*.yaml` + `terraform apply` to change them.
- Genuine fixes kept from the Roche run: MongoDB uses `public.ecr.aws/docker/library/mongo:8.0`
  (avoids Docker Hub rate limit) and the app sets `HOSTNAME=0.0.0.0` (Next standalone binds
  to all interfaces, so port-forward works).
- Dead Roche files (`trust-*.json`, `REPLICA-NOTES.md`, duplicate root `helm-values/`, orphan
  `ebs-driver.yaml`/`storageclass.yaml`/`iam_policy.json` under helm-values) have been removed.
- The ALB controller `helm-values/alb_controller-1.13.3.yaml` must match THIS cluster:
  `region: ap-south-1`, `vpcId: <the VPC module creates>`, `clusterName: tws-eks-cluster`.
  Wrong values here CrashLoop the controller or make it reject the subnets.
- To add HTTPS later: own a domain, request an ACM cert in ap-south-1, then add the cert ARN +
  `listen-ports '[{"HTTP":80},{"HTTPS":443}]'` + `ssl-redirect` + host to the app ingress
  (`kubernetes/10-ingress.yaml`) and the dashboard ingresses, and switch each `group.name`-shared
  member to HTTPS together.
```
