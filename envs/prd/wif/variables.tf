variable "project" {
  description = "Projeto GCP de produção."
  type        = string
  default     = "biahflow-prd"
}

variable "region" {
  description = "Região padrão do provider google neste stack."
  type        = string
  default     = "us-east1"
}

variable "state_bucket" {
  description = "Bucket de estado de produção. Não é gerenciado pelo Terraform — este stack só concede acesso a ele."
  type        = string
  default     = "biahflow-prd-tfstate"
}

variable "infra_repo" {
  description = "Repositório que roda o CI desta infraestrutura e impersona a SA infra-deploy."
  type        = string
  default     = "biahflow/infra"
}

variable "repos_allowlist" {
  description = <<-EOT
    Repositórios autorizados no pool de produção. Só a infraestrutura por
    enquanto: repositório de aplicação entra quando houver aplicação em prd.
  EOT
  type        = list(string)
  default     = ["biahflow/infra"]
}

variable "deploy_sa_repos" {
  description = <<-EOT
    Repositórios que impersonam a SA `prd-deploy`. Vazia de propósito: a SA
    existe desde já para que os papéis de deploy sejam concedidos com calma, mas
    ninguém a usa até haver aplicação em produção.
  EOT
  type        = list(string)
  default     = []
}

variable "infra_deploy_roles" {
  description = "Papéis de projeto da SA infra-deploy — o que o CI desta infraestrutura pode alterar em prd."
  type        = list(string)
  default = [
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/run.admin",
    "roles/resourcemanager.projectIamAdmin",
  ]
}
