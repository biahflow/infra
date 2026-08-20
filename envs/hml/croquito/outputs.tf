output "web_url" {
  description = "URL run.app do serviço público (origem da borda Cloudflare)."
  value       = module.web.url
}

output "api_url" {
  description = "URL run.app interna da API (destino do proxy /api/)."
  value       = module.api.url
}

output "worker_url" {
  description = "URL run.app interna do worker (endpoint do push Pub/Sub)."
  value       = module.worker.url
}

output "auth_url" {
  description = "URL run.app interna do Keycloak (destino de /auth/)."
  value       = module.auth.url
}

output "runtime_service_accounts" {
  description = "SAs de runtime que o CI do croquito atribui a cada serviço."
  value = {
    api    = google_service_account.api.email
    worker = google_service_account.worker.email
    auth   = google_service_account.auth.email
  }
}

output "storage_sa" {
  description = "SA dona da chave HMAC do interop S3."
  value       = google_service_account.storage.email
}

output "hmac_access_id" {
  description = <<-EOT
    `access_id` da chave HMAC corrente. É a metade pública do par — a outra metade só existe
    no secret e no state. Serve para conferir, sem abrir segredo nenhum, se o que a API assina
    é a chave que este stack criou.
  EOT
  value       = google_storage_hmac_key.storage.access_id
}

output "docai_processor_name" {
  description = <<-EOT
    Nome completo do processador de OCR do Document AI
    (projects/.../locations/us/processors/...). É o valor literal do env
    CROQUITO_DOCAI_PROCESSOR no deploy-hml do biahflow/croquito — com ele o worker
    monta o braço Document AI; sem ele, segue no Cloud Vision (ADR-0037 de lá).
  EOT
  value       = google_document_ai_processor.ocr.id
}
