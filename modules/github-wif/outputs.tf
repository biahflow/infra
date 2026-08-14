output "provider_name" {
  description = "Nome completo do provider OIDC (`projects/<nº>/locations/global/workloadIdentityPools/<pool>/providers/<provider>`), valor esperado por google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.this.name
}

output "pool_name" {
  description = "Nome completo do pool (`projects/<nº>/locations/global/workloadIdentityPools/<pool>`), base dos principalSet."
  value       = google_iam_workload_identity_pool.this.name
}

output "project_number" {
  description = "Número do projeto GCP, necessário para montar principalSet fora do módulo."
  value       = data.google_project.this.number
}

output "deploy_sa_email" {
  description = "E-mail da service account de deploy criada pelo módulo."
  value       = google_service_account.deploy.email
}
