module "filebeat" {
  source = "../modules/alb_controller"

  namespace  = "logging"
  repository = "https://helm.elastic.co"

  app = {
    name             = "filebeat"
    description      = "filebeat"
    version          = "8.5.1"
    chart            = "filebeat"
    create_namespace = true
    force_update     = true
    wait             = false
    recreate_pods    = false
    deploy           = 1
  }

  # NOTE: file() (NOT templatefile()) — the ${NODE_NAME}/${ELASTICSEARCH_*} tokens in this
  # file are RUNTIME container env-var references resolved by Filebeat inside the pod, NOT
  # Terraform variables. templatefile() would try to interpolate them and fail.
  values = [file("${path.module}/helm-values/filebeat.yaml")]

  # Filebeat ships logs TO Elasticsearch, so install ES first.
  depends_on = [module.elasticsearch]
}
