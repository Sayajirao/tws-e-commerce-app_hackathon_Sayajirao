module "elasticsearch" {
  source = "../modules/alb_controller"

  namespace  = "logging"
  repository = "https://helm.elastic.co"

  app = {
    name             = "elasticsearch"
    description      = "elasticsearch"
    version          = "8.5.1"
    chart            = "elasticsearch"
    create_namespace = true
    force_update     = true
    wait             = false
    recreate_pods    = false
    deploy           = 1
  }

  # NOTE: file() (NOT templatefile()) — the values file has no Terraform ${} vars.
  values = [file("${path.module}/helm-values/elasticsearch.yaml")]
}
