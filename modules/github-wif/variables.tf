variable "project" {
  description = "Projeto GCP onde o pool de identidade e a service account de deploy vivem."
  type        = string
}

variable "pool_id" {
  description = "Identificador do Workload Identity Pool."
  type        = string
  default     = "github"
}

variable "provider_id" {
  description = "Identificador do provider OIDC do GitHub Actions dentro do pool."
  type        = string
  default     = "github"
}

variable "repos_allowlist" {
  description = <<-EOT
    Repositórios (owner/repo) autorizados a trocar o token OIDC do GitHub por
    credencial do pool. Vira a attributeCondition `attribute.repository in [...]`
    do provider — a ordem da lista é significativa apenas para manter o diff
    estável contra o valor já aplicado.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.repos_allowlist) > 0
    error_message = "repos_allowlist não pode ser vazia — um provider sem condição aceitaria qualquer repositório do GitHub."
  }
}

variable "deploy_sa_id" {
  description = "account_id da service account de deploy criada no projeto (ex.: hml-deploy)."
  type        = string
}

variable "pool_display_name" {
  description = "Nome de exibição do pool. Em recursos importados, declarar o valor vivo para não esvaziá-lo."
  type        = string
  default     = null
}

variable "provider_display_name" {
  description = "Nome de exibição do provider OIDC. Em recursos importados, declarar o valor vivo para não esvaziá-lo."
  type        = string
  default     = null
}

variable "deploy_sa_display_name" {
  description = "Nome de exibição da SA de deploy. Em recursos importados, declarar o valor vivo para não esvaziá-lo."
  type        = string
  default     = null
}

variable "deploy_sa_repos" {
  description = <<-EOT
    Repositórios (owner/repo) que podem impersonar a service account de deploy.
    Vira um binding AUTORITATIVO de `roles/iam.workloadIdentityUser` na SA: quem
    não estiver aqui perde o acesso. Lista vazia cria a SA sem nenhum binding.
  EOT
  type        = list(string)
  default     = []
}
