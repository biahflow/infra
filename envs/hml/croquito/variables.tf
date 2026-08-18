variable "project" {
  description = "Projeto GCP de homologação."
  type        = string
  default     = "biahflow-hml"
}

variable "region" {
  description = "Região dos serviços e buckets do croquito em hml."
  type        = string
  default     = "us-east1"
}

variable "host_publico" {
  description = <<-EOT
    Hostname público da interface unificada (borda Cloudflare em
    envs/hml/croquito-edge). Entra no CORS do bucket de artefatos — o presigned
    PUT/GET do browser fala direto com o GCS, único lugar onde CORS sobrevive ao
    desenho same-origin.
  EOT
  type        = string
  default     = "croquito-hml.biahflow.ai"
}

variable "vpc_network" {
  description = "VPC existente usada pelo Direct VPC egress do serviço web (proxy)."
  type        = string
  default     = "hml"
}

# A subnet do egress do web é recurso deste stack (google_compute_subnetwork.
# web_egress), fora da lista do Cloud NAT — ver envs/hml/rede.

variable "image_inicial" {
  description = <<-EOT
    Imagem com que os serviços nascem. Só vale na criação: a partir do primeiro
    deploy, a revisão é do CI do repositório biahflow/croquito. O hello do Cloud
    Run existe para o serviço subir saudável antes da primeira imagem real.

    Cuidado que custou quatro dias de homologação: este hello é para o serviço
    **nascer**, não para diagnosticar serviço em produção. Em 2026-08-14 ele foi
    posto de volta em `croquito-scene-hml` num teste de roteamento e ficou lá,
    respondendo 200 em quase todo caminho enquanto a API não existia.
  EOT
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "neon_project_id" {
  description = "Projeto Neon que hospeda o PostgreSQL de hml."
  type        = string
  default     = "empty-glitter-27235439"
}

variable "neon_branch" {
  description = <<-EOT
    Branch do Neon que a homologação usa. `staging` é uma branch filha de
    `production`, com endpoint e senha de role próprios — por isso host e senha
    nunca são escritos à mão neste stack: eles saem da branch declarada aqui.
  EOT
  type        = string
  default     = "staging"
}

variable "neon_role" {
  description = "Role do Postgres usada pela API, pelo worker e pelo Keycloak."
  type        = string
  default     = "neondb_owner"
}

variable "neon_database" {
  description = "Banco dentro da branch, compartilhado pela aplicação e pelo Keycloak em schemas próprios."
  type        = string
  default     = "neondb"
}

# Um schema por componente, e nenhum dos dois é `public`. Os dois schemas são criados fora
# daqui, junto com a branch do Neon: este stack lê o banco e não manda nele (ADR-0031, D1.1).
# Schema ausente é falha barulhenta no boot, nunca queda silenciosa para `public` — foi
# exatamente essa queda que misturou as tabelas do Keycloak com as da aplicação.
variable "croquito_schema" {
  description = "Schema da aplicação (API e worker) dentro do banco de homologação."
  type        = string
  default     = "croquito"
}

variable "keycloak_schema" {
  description = "Schema do Keycloak dentro do mesmo banco."
  type        = string
  default     = "keycloak"
}
