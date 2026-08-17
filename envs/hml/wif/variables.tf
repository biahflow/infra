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
    Repositórios autorizados no pool de hml. O caminho aqui é a claim
    `assertion.repository` do token do GitHub: quando um repo muda de dono, ele
    para de autenticar até esta lista mudar junto — foi o caso de `biahflow/site`
    (migrou de dcamppos83 em 2026-08-14) e de `biahflow/portal` (ex
    `dcamppos83/biahflow-portal`, migrado em 2026-08-17).
  EOT
  type        = list(string)
  default = [
    "dcamppos83/biahflow-portal-cliente",
    "biahflow/portal",
    "biahflow/site",
    "dcamppos83/OikOS",
    "biahflow/eliseu",
    "biahflow/infra",
    "biahflow/croquito",
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
    "biahflow/portal",
    "biahflow/site",
    "dcamppos83/OikOS",
    "biahflow/eliseu",
    "biahflow/croquito",
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
    # envs/hml/croquito cria buckets, Pub/Sub e cascas de secret com IAM em nível
    # de recurso — os três admins abaixo existem por causa dele.
    "roles/storage.admin",
    "roles/pubsub.admin",
    "roles/secretmanager.admin",
    # Atualizar um serviço Cloud Run re-valida a leitura da imagem no Artifact
    # Registry com a credencial de quem aplica; sem reader, o apply de
    # envs/hml/servicos falha em 403 (visto no primeiro apply do croquito).
    "roles/artifactregistry.reader",
    # Zona DNS privada run.app da VPC (ingress interno alcançável pelo proxy).
    "roles/dns.admin",
    # envs/hml/rede adota o router/NAT e envs/hml/croquito cria a subnet do web.
    "roles/compute.networkAdmin",
  ]
}
