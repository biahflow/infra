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
    `assertion.repository` do token do GitHub: quando um repo muda de dono ou de
    nome, ele para de autenticar até esta lista mudar junto — foi o caso de
    `biahflow/site` (migrou de dcamppos83 em 2026-08-14), de `biahflow/portal` (ex
    `dcamppos83/biahflow-portal`, migrado em 2026-08-17) e de
    `biahflow/portal-cliente` (ex `dcamppos83/biahflow-portal-cliente`, migrado no
    mesmo dia — o último repositório de produto que estava na conta pessoal).
    Em 2026-08-19 `biahflow/portal` virou `biahflow/cockpit` (ADR 0030 de lá): o
    redirect do GitHub cobre clone e push, mas a claim do token OIDC carrega o
    nome novo — a lista acompanha.
    Em 2026-08-24 `biahflow/cockpit` virou `biahflow/pulse`: o deploy-hml do
    Pulse passou a falhar em `google-github-actions/auth` com
    `unauthorized_client` / attribute condition, exatamente este modo.
  EOT
  type        = list(string)
  default = [
    "biahflow/portal-cliente",
    "biahflow/pulse",
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
    "biahflow/portal-cliente",
    "biahflow/pulse",
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
    # `storage.admin` NÃO cobre chave HMAC do interop S3: `storage.hmacKeys.*`
    # vive só neste papel, e sem ele o apply de envs/hml/croquito falha em 403 ao
    # criar a chave (visto em 2026-08-18).
    "roles/storage.hmacKeyAdmin",
    # Atualizar um serviço Cloud Run re-valida a leitura da imagem no Artifact
    # Registry com a credencial de quem aplica; sem reader, o apply de
    # envs/hml/servicos falha em 403 (visto no primeiro apply do croquito).
    "roles/artifactregistry.reader",
    # Zona DNS privada run.app da VPC (ingress interno alcançável pelo proxy).
    "roles/dns.admin",
    # envs/hml/rede adota o router/NAT e envs/hml/croquito cria a subnet do web.
    "roles/compute.networkAdmin",
    # envs/hml/croquito habilita APIs de projeto (`google_project_service`, hoje
    # vision.googleapis.com para o braço de OCR da F-009); sem este papel o apply
    # falha em 403 "Permission denied to enable service" (visto em 2026-08-19).
    "roles/serviceusage.serviceUsageAdmin",
    # envs/hml/croquito cria o processador de OCR do Document AI
    # (`google_document_ai_processor`, braço alternativo do worker — ADR-0037 do
    # croquito); criar/gerir processador exige papel de admin do produto.
    "roles/documentai.admin",
  ]
}
