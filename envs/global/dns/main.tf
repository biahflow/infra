# Zona Cloudflare compartilhada. O stack é fino de propósito: existe para
# publicar o `zone_id` e para ser o lugar óbvio dos registros que não pertencem
# a nenhum ambiente. Registros de um serviço específico ficam com o stack do
# serviço (ex.: `envs/hml/eliseu-demo`).

provider "cloudflare" {
  # Token via CLOUDFLARE_API_TOKEN (não versionado).
  # Escopo mínimo: Zone -> Read e Zone -> DNS -> Edit na zona configurada.
}

data "cloudflare_zone" "this" {
  name = var.cloudflare_zone
}
