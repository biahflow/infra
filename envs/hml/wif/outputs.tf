output "wif_provider" {
  description = "Nome completo do provider OIDC de hml — valor da variável de repositório WIF_PROVIDER_HML."
  value       = module.wif.provider_name
}

output "deploy_sa_email" {
  description = "SA usada pelos repositórios de aplicação para deploy em hml."
  value       = module.wif.deploy_sa_email
}

output "infra_deploy_sa_email" {
  description = "SA usada por este repositório para aplicar Terraform em hml."
  value       = google_service_account.infra_deploy.email
}
