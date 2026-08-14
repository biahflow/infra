output "wif_provider" {
  description = "Nome completo do provider OIDC de prd — valor da variável de repositório WIF_PROVIDER_PRD."
  value       = module.wif.provider_name
}

output "deploy_sa_email" {
  description = "SA reservada para deploy de aplicação em prd (ainda sem binding de uso)."
  value       = module.wif.deploy_sa_email
}

output "infra_deploy_sa_email" {
  description = "SA usada por este repositório para aplicar Terraform em prd."
  value       = google_service_account.infra_deploy.email
}
