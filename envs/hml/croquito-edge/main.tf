# Borda do croquito em hml: Cloudflare proxied na frente do Cloud Run.
#
# Padrão do portal-cliente, e NÃO o do eliseu-demo: sem domain mapping do
# Google (o proxy da Cloudflare quebra a emissão do certificado gerenciado),
# o CNAME é proxied e um Worker reescreve o hostname da URL para a origem
# run.app. Com isso a Cloudflare dá CDN (os assets com hash saem com
# `Cache-Control: immutable` do nginx) e WAF/anti-DDoS do plano free — o papel
# que CloudFront+WAF têm no desenho AWS de produção.
#
# Limite declarado: a URL run.app da origem continua alcançável direto
# (bypass da borda). A autenticação do produto não depende da borda — o bypass
# perde só CDN/WAF.
#
# O token CLOUDFLARE_API_TOKEN deste stack precisa, além de Zone->Read e
# Zone->DNS->Edit, de Account->Workers Scripts->Edit (o script e a rota).
#
# Primeiro apply ficou skipped no merge inicial (o stack croquito falhou antes);
# esta nota também serve para o paths-filter arrastar o stack no reapply.

provider "cloudflare" {
  # Token via variável de ambiente CLOUDFLARE_API_TOKEN (não versionado).
}

data "cloudflare_zone" "esta" {
  name = var.cloudflare_zone
}

resource "cloudflare_record" "croquito" {
  zone_id = data.cloudflare_zone.esta.id
  name    = var.subdominio
  type    = "CNAME"
  content = var.origem

  # Proxied de propósito: em DNS-only o browser iria direto ao Cloud Run com
  # `Host: croquito-hml.biahflow.ai`, que a origem não reconhece (404 do
  # Google). O Worker abaixo só existe porque o tráfego passa pela borda.
  proxied = true
  ttl     = 1 # automático; obrigatório no schema, ignorado quando proxied
  comment = "croquito hml — gerenciado por envs/hml/croquito-edge"
}

resource "cloudflare_workers_script" "proxy" {
  account_id = data.cloudflare_zone.esta.account_id
  name       = "croquito-hml-proxy"
  module     = true

  content = templatefile("${path.module}/worker-do-croquito.js.tftpl", {
    origem = var.origem
  })
}

resource "cloudflare_workers_route" "proxy" {
  zone_id     = data.cloudflare_zone.esta.id
  pattern     = "${var.subdominio}.${var.cloudflare_zone}/*"
  script_name = cloudflare_workers_script.proxy.name
}
