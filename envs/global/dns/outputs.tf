output "zone_id" {
  description = "ID da zona Cloudflare da biahflow."
  value       = data.cloudflare_zone.this.id
}

output "zone_name" {
  description = "Nome da zona, para compor hostnames."
  value       = data.cloudflare_zone.this.name
}
