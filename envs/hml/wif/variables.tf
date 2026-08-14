variable "project" {
  description = "Projeto GCP de homologação."
  type        = string
  default     = "biahflow-hml"
}

variable "region" {
  description = "Região padrão do provider google neste stack."
  type        = string
  default     = "us-east1"
}

variable "state_bucket" {
  description = "Bucket de estado de hml. Não é gerenciado pelo Terraform — este stack só concede acesso a ele."
  type        = string
  default     = "biahflow-hml-tfstate"
}

variable "infra_repo" {
  description = "Repositório que roda o CI desta infraestrutura e impersona a SA infra-deploy."
  type        = string
  default     = "biahflow/infra"
}

variable "repos_allowlist" {
  description = <<-EOT
    Repositórios autorizados no pool de hml. Os cinco primeiros são o estado já
    aplicado; `biahflow/infra` é o acréscimo desta infraestrutura — o primeiro
    plan pós-import mostra exatamente essa mudança.
  EOT
  type        = list(string)
  default = [
    "dcamppos83/biahflow-portal-cliente",
    "dcamppos83/biahflow-portal",
    "dcamppos83/biahflow-site",
    "dcamppos83/OikOS",
    "biahflow/eliseu",
    "biahflow/infra",
  ]
}

variable "deploy_sa_repos" {
  description = <<-EOT
    Repositórios que impersonam a SA `hml-deploy` (deploy de aplicação). A infra
    não entra aqui: ela usa a `infra-deploy`, com outro conjunto de permissões.
  EOT
  type        = list(string)
  default = [
    "dcamppos83/biahflow-portal-cliente",
    "dcamppos83/biahflow-portal",
    "dcamppos83/biahflow-site",
    "dcamppos83/OikOS",
    "biahflow/eliseu",
  ]
}

variable "infra_deploy_roles" {
  description = "Papéis de projeto da SA infra-deploy — o que o CI desta infraestrutura pode alterar em hml."
  type        = list(string)
  default = [
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/run.admin",
    "roles/resourcemanager.projectIamAdmin",
  ]
}
