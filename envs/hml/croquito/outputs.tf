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

output "medicao_url" {
  description = "URL run.app interna do servidor de medição (destino de /medicao/api/)."
  value       = module.medicao.url
}

output "auth_url" {
  description = "URL run.app interna do Keycloak (destino de /auth/)."
  value       = module.auth.url
}

output "runtime_service_accounts" {
  description = "SAs de runtime que o CI do croquito atribui a cada serviço."
  value = {
    api     = google_service_account.api.email
    worker  = google_service_account.worker.email
    medicao = google_service_account.medicao.email
    auth    = google_service_account.auth.email
  }
}

output "storage_sa" {
  description = "SA dona da chave HMAC do interop S3 (chave criada fora do TF)."
  value       = google_service_account.storage.email
}
