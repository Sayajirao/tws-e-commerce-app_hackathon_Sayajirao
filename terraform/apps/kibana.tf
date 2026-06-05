module "kibana" {
  source = "../modules/alb_controller"

  namespace  = "logging"
  repository = "https://helm.elastic.co"

  app = {
    name             = "kibana"
    description      = "kibana"
    version          = "8.5.1"
    chart            = "kibana"
    create_namespace = true
    force_update     = true
    wait             = false
    recreate_pods    = false
    deploy           = 1
  }

  # NOTE: file() (NOT templatefile()) — the values file has no Terraform ${} vars.
  values = [file("${path.module}/helm-values/kibana.yaml")]

  # Kibana is the UI for Elasticsearch, so install ES first.
  depends_on = [module.elasticsearch]
}
