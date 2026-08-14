output "nome" {
  description = "Nome do serviço, para amarrar domain mapping e deploys do CI."
  value       = google_cloud_run_v2_service.this.name
}

output "url" {
  description = "URL `run.app` gerada pelo Cloud Run."
  value       = google_cloud_run_v2_service.this.uri
}

output "id" {
  description = "ID completo do serviço."
  value       = google_cloud_run_v2_service.this.id
}
