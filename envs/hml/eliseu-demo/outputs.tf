output "url_demo" {
  description = "URL pública do demo."
  value       = "https://${var.subdominio}.${var.cloudflare_zone}"
}

output "status_domain_mapping" {
  description = "Status bruto do domain mapping do Cloud Run (condições e registros reportados pela API do Google)."
  value       = google_cloud_run_domain_mapping.demo.status
}
