# ---------------------------------------------------------------------------------
# metrics-server (personal account).
#
# Previously this was only a README note ("helm install it manually"). It's now
# proper code so the cluster comes up complete from `terraform apply`.
#
# WHAT IT DOES: scrapes CPU/memory from each kubelet and serves the Kubernetes
# Metrics API (metrics.k8s.io). That API backs:
#   - `kubectl top nodes` / `kubectl top pods`
#   - the HorizontalPodAutoscaler in kubernetes/11-hpa.yaml (needs CPU% to scale)
#
# NOTE: NOT the same as Prometheus. metrics-server = lightweight, in-memory, last
# ~15s of data, for autoscaling. Prometheus = full time-series history, for dashboards.
#
# --kubelet-insecure-tls: EKS kubelets serve metrics with a self-signed cert that
# metrics-server can't verify by default, so it's skipped. Standard on EKS.
# ---------------------------------------------------------------------------------
module "metrics_server" {
  source = "../modules/alb_controller"

  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"

  app = {
    name             = "metrics-server"
    description      = "metrics-server"
    version          = "3.12.2"
    chart            = "metrics-server"
    create_namespace = false
    force_update     = true
    wait             = false
    recreate_pods    = false
    deploy           = 1
  }

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}
