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

# As duas chaves de provider da suite real (F-009). SEM default de propósito:
# plan/apply falham fail-closed se a env `TF_VAR_openai_api_key`/
# `TF_VAR_anthropic_api_key` não existir, em vez de gravar secret vazio ou usar
# um valor placeholder silencioso. Só o worker recebe suas SAs de leitura, e o
# valor entra write-only no Secret Manager (module.secrets, `valores_wo`) —
# nunca fica no state deste stack. Origem: GitHub Actions secrets
# `CROQUITO_OPENAI_API_KEY`/`CROQUITO_ANTHROPIC_API_KEY` do repositório
# `biahflow/infra`, injetados como `TF_VAR_*` em `.github/workflows/plan.yml` e
# `apply.yml`, mesmo padrão do `NEON_API_KEY`.
variable "openai_api_key" {
  description = "Chave da API OpenAI para a suite de providers reais do croquito em hml."
  type        = string
  sensitive   = true

  # A ausência da env falha sozinha (sem default), mas um GitHub Actions secret
  # inexistente/vazio resolve para "" — que sem esta validação viraria uma versão
  # de secret vazia e válida. Fail closed também para o vazio.
  validation {
    condition     = length(var.openai_api_key) > 0
    error_message = "openai_api_key vazio: confira o GitHub Actions secret CROQUITO_OPENAI_API_KEY do repositório."
  }
}

variable "anthropic_api_key" {
  description = "Chave da API Anthropic para a suite de providers reais do croquito em hml."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.anthropic_api_key) > 0
    error_message = "anthropic_api_key vazio: confira o GitHub Actions secret CROQUITO_ANTHROPIC_API_KEY do repositório."
  }
}

# Gatilho de rotação write-only (secret_data_wo_version) para as duas chaves
# acima — o Terraform não guarda o valor delas, então não tem como perceber
# sozinho que mudou. Incrementar este número troca as duas versões juntas;
# rotação independente por chave é acréscimo aditivo (duas variáveis), não
# necessário hoje.
variable "providers_api_key_version" {
  description = "Gatilho de rotação write-only para as chaves OpenAI/Anthropic de hml."
  type        = number
  default     = 1
}
