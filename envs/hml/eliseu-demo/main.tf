# DNS de demo: aponta eliseu-demo.biahflow.ai (Cloudflare) para o Cloud Run
# eliseu-hml (biahflow-hml, us-east1) via domain mapping. O domain
# mapping é quem faz o Cloud Run reconhecer o hostname e emitir o
# certificado gerenciado; sem ele, o DNS sozinho não é suficiente.
#
# Veio de plataforma-oikos/ops/terraform com os endereços de recurso intactos
# (data.cloudflare_zone.this, cloudflare_record.demo,
# google_cloud_run_domain_mapping.demo) — é por eles que o estado local antigo é
# migrado para o backend GCS. NÃO renomear nem mover para módulo.

provider "cloudflare" {
  # Token via variável de ambiente CLOUDFLARE_API_TOKEN (não versionado).
  # Escopo mínimo: Zone -> DNS -> Edit e Zone -> Read na zona configurada.
}

provider "google" {
  project = var.gcp_project
  region  = var.regiao
}

data "cloudflare_zone" "this" {
  name = var.cloudflare_zone
}

resource "google_cloud_run_domain_mapping" "demo" {
  name     = "${var.subdominio}.${var.cloudflare_zone}"
  location = var.regiao

  metadata {
    namespace = var.gcp_project
  }

  spec {
    route_name = var.servico
  }
}

resource "cloudflare_record" "demo" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.subdominio
  type    = "CNAME"
  content = "ghs.googlehosted.com"
  # DNS-only (nuvem cinza): o TLS é o certificado gerenciado do Google:
  # proxy da Cloudflare (nuvem laranja) quebra a emissão do certificado.
  proxied = false
  ttl     = 1 # auto
}
