# Homologação do croquito: quatro serviços Cloud Run com um único host público.
#
# Só o `croquito-web-hml` (nginx: dois SPAs + proxy same-origin) aceita tráfego
# da internet; API e Keycloak têm ingress interno e só são alcançados pelo proxy,
# via Direct VPC egress. O worker é interno e privado: quem o invoca é a push
# subscription do Pub/Sub, com OIDC token da SA dedicada.
#
# Segredo é Terraform desde 2026-08-18: as cascas, o IAM e o valor corrente saem
# do módulo `secret-manager`, e a chave HMAC do interop S3 nasce aqui. A política
# anterior — casca no TF, valor por `gcloud secrets versions add` — caiu porque
# coordenada de banco que só um humano sabe atualizar é coordenada que ninguém
# atualiza: o endpoint do Neon mudou, o secret continuou apontando para o antigo,
# o Keycloak parou de subir e o job de schema barrou a esteira do croquito por
# quatro dias sem que nada no repositório soubesse dizer isso. A contrapartida
# está declarada no README do módulo: o valor mora no state, e quem lê o state lê
# os segredos.
#
# O que este stack NÃO faz, de propósito:
#   - env/imagem/volumes dos serviços (CI do biahflow/croquito é o dono — ver
#     lifecycle do módulo cloud-run-service).

provider "google" {
  project = var.project
  region  = var.region
}

# `NEON_API_KEY` no ambiente. Escopo de leitura basta para o que este stack faz.
provider "neon" {}

data "google_project" "este" {
  project_id = var.project
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.este.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# APIs do projeto.
#
# Nenhum `google_project_service` existia neste repositório antes deste recurso
# (verificado por grep em todo o `biahflow/infra`) — as APIs que os outros
# serviços deste stack usam (Cloud Run, Pub/Sub, Secret Manager) já estavam
# habilitadas no projeto `biahflow-hml` por fora do Terraform, e nenhum stack
# assumiu a propriedade delas. Não há, portanto, um padrão local a seguir; este
# é o recurso padrão do provider `google` para o caso, com o mínimo de opção.
# `disable_on_destroy = false` porque uma API de projeto pode ter outro
# consumidor fora deste stack — destruir este recurso não deve desligá-la.
# ---------------------------------------------------------------------------

resource "google_project_service" "vision" {
  project = var.project
  service = "vision.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "documentai" {
  project = var.project
  service = "documentai.googleapis.com"

  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Processador de OCR do Document AI — braço `ocr` alternativo do worker.
#
# O adapter no biahflow/croquito (ADR-0037 de lá) monta o Document AI no lugar
# do Cloud Vision quando `CROQUITO_DOCAI_PROCESSOR` aponta este processador;
# sem o env, o worker segue no Vision. O nome completo sai no output
# `docai_processor_name` e é colado literalmente naquele env pelo deploy-hml
# da aplicação (env de container é do CI da aplicação, não deste stack).
#
# `location` é multi-região própria do produto (`us`/`eu`) — Document AI não
# existe em `us-east1`. Escolha `us` por decisão humana de 2026-08-20: mesmo
# hemisfério do stack e mesmo enquadramento LGPD do Vision atual.
# ---------------------------------------------------------------------------

resource "google_document_ai_processor" "ocr" {
  project      = var.project
  location     = var.docai_location
  display_name = "croquito-hml-ocr"
  type         = "OCR_PROCESSOR"

  depends_on = [google_project_service.documentai]
}

# Diferente do Vision (que qualquer chamador autenticado usa com a API ligada),
# o Document AI é resource-scoped: quem chama `:process` precisa de
# `roles/documentai.apiUser`. Só o worker chama.
resource "google_project_iam_member" "worker_documentai" {
  project = var.project
  role    = "roles/documentai.apiUser"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

# ---------------------------------------------------------------------------
# Service accounts de runtime (uma por serviço) + as duas de função específica.
# A atribuição runtime SA -> serviço é do CI (template.service_account está no
# ignore_changes do módulo); aqui elas existem e recebem IAM de recurso.
# ---------------------------------------------------------------------------

resource "google_service_account" "web" {
  account_id   = "croquito-web-hml"
  display_name = "Runtime do nginx do croquito em hml (sem permissão nenhuma)"
}

resource "google_service_account" "api" {
  account_id   = "croquito-api-hml"
  display_name = "Runtime da API do croquito em hml"
}

resource "google_service_account" "worker" {
  account_id   = "croquito-worker-hml"
  display_name = "Runtime do worker do croquito em hml"
}

resource "google_service_account" "auth" {
  account_id   = "croquito-auth-hml"
  display_name = "Runtime do Keycloak do croquito em hml"
}

# Dona da chave HMAC do interop S3.
resource "google_service_account" "storage" {
  account_id   = "croquito-hml-storage"
  display_name = "Acesso a artefatos via interop S3/HMAC (croquito hml)"
}

# Identidade do push do Pub/Sub ao worker.
resource "google_service_account" "push" {
  account_id   = "croquito-hml-push"
  display_name = "OIDC do push Pub/Sub -> worker (croquito hml)"
}

# Os serviços nascem com as runtime SAs acima; quem os cria (infra-deploy, e a
# hml-deploy nos deploys seguintes já tem serviceAccountUser de projeto) precisa
# de actAs nelas. Binding por SA, nunca na default de compute.
locals {
  runtime_sas = {
    web    = google_service_account.web
    api    = google_service_account.api
    worker = google_service_account.worker
    auth   = google_service_account.auth
    # Criar a push subscription com oidc_token também exige actAs na SA de push
    # por quem aplica — o Pub/Sub valida na criação, não só na entrega.
    push = google_service_account.push
  }
}

resource "google_service_account_iam_member" "infra_deploy_actas" {
  for_each = local.runtime_sas

  service_account_id = each.value.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:infra-deploy@${var.project}.iam.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# Serviços Cloud Run.
# ---------------------------------------------------------------------------

# Subnet PRÓPRIA do egress do web, fora da lista do Cloud NAT (envs/hml/rede).
# Medido em 2026-08-14: na hml-us-east1, o NAT SNATeava o egress e o ingress
# interno dos backends recusava o proxy como tráfego externo. Sem NAT, o
# caminho ao Google é o Private Google Access — classificado como interno.
resource "google_compute_subnetwork" "web_egress" {
  name          = "hml-us-east1-croquito-web"
  network       = var.vpc_network
  region        = var.region
  ip_cidr_range = "10.20.1.0/24"

  private_ip_google_access = true
}

module "web" {
  source = "../../../modules/cloud-run-service"

  nome            = "croquito-web-hml"
  project         = var.project
  region          = var.region
  image_inicial   = var.image_inicial
  service_account = google_service_account.web.email

  publico     = true
  vpc_network = var.vpc_network
  vpc_subnet  = google_compute_subnetwork.web_egress.name

  min_instances = 0
  max_instances = 3

  depends_on = [google_service_account_iam_member.infra_deploy_actas]
}

module "api" {
  source = "../../../modules/cloud-run-service"

  # Renomeado de croquito-api-hml em 2026-08-14: a identidade antiga ficou com
  # o roteamento quebrado no GFE (404 em todos os caminhos com workload real,
  # hello roteando — bug de plataforma). Nome novo = registro novo.
  nome            = "croquito-scene-hml"
  project         = var.project
  region          = var.region
  image_inicial   = var.image_inicial
  service_account = google_service_account.api.email

  # Interno + invoker aberto: a barreira de rede é o ingress; a autenticação é o
  # JWT da aplicação. Exigir IAM aqui obrigaria o nginx a cunhar ID tokens.
  publico = true
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  min_instances = 0
  max_instances = 3

  # Mesma razão do Keycloak: o secret vem antes do serviço, para que uma revisão
  # nova nunca nasça lendo credencial velha.
  depends_on = [
    google_service_account_iam_member.infra_deploy_actas,
    module.secrets,
  ]
}

module "worker" {
  source = "../../../modules/cloud-run-service"

  # Renomeado de croquito-worker-hml pela mesma razão do croquito-scene-hml.
  nome            = "croquito-jobs-hml"
  project         = var.project
  region          = var.region
  image_inicial   = var.image_inicial
  service_account = google_service_account.worker.email

  publico = false
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  min_instances = 0
  max_instances = 3

  depends_on = [
    google_service_account_iam_member.infra_deploy_actas,
    module.secrets,
  ]
}

# O quinto serviço, `croquito-medicao-hml`, saiu daqui em 2026-08-18. A F-003 do croquito
# migrou a medição para a API `/v1` e removeu o modo hospedado do código, da esteira e da
# borda; o serviço foi removido do projeto por ato humano, e o stack ainda o declarava — o
# próximo apply o teria recriado, ressuscitando um caminho que o produto já não tem. Com ele
# saem a runtime SA `croquito-medicao-hml` — que, ao contrário do serviço, ainda existe e
# será destruída de fato — e o bucket `croquito-hml-rounds`.

module "auth" {
  source = "../../../modules/cloud-run-service"

  nome            = "croquito-auth-hml"
  project         = var.project
  region          = var.region
  image_inicial   = var.image_inicial
  service_account = google_service_account.auth.email

  publico = true
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  # Keycloak com KC_CACHE=local não forma cluster: uma instância, sempre de pé
  # (cold start de ~20-40s derrubaria o primeiro login e o JWKS da API).
  min_instances = 1
  max_instances = 1

  # O secret vem antes do serviço, e a razão é concreta: mexer no template cria
  # revisão nova, revisão nova lê `:latest` ao subir, e `min_instances = 1` exige
  # que ela fique **saudável** para o apply terminar. Sem esta ordem, a revisão
  # nasce com a credencial velha e morre no startup probe — foi o que aconteceu no
  # apply de 2026-08-18, que subiu a revisão 00017 do Keycloak contra o host morto.
  depends_on = [
    google_service_account_iam_member.infra_deploy_actas,
    module.secrets,
  ]
}

# A push subscription invoca o worker com o OIDC token da SA dedicada.
resource "google_cloud_run_v2_service_iam_member" "worker_push_invoker" {
  project  = var.project
  location = var.region
  name     = module.worker.nome
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.push.email}"
}

# ---------------------------------------------------------------------------
# Buckets.
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "artifacts" {
  name     = "croquito-hml-artifacts"
  location = upper(var.region)

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # O browser fala direto com o GCS via URL presignada (interop S3): o preflight
  # do PUT precisa deste CORS. Único CORS do desenho — o resto é same-origin.
  cors {
    origin          = ["https://${var.host_publico}"]
    method          = ["PUT", "GET", "HEAD"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }

  # Retenção prometida em docs/security/DATA_RETENTION.md (croquito): PDF original,
  # páginas renderizadas, respostas brutas de provider e pacote exportado expiram em
  # 7 dias. Este é o único bucket de artefatos do ambiente — a regra vale para todo
  # objeto nele, não só para o caminho de providers reais da F-009.
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}

# API e worker acessam artefatos com a HMAC da SA de storage; a permissão da
# chave é a permissão da SA.
resource "google_storage_bucket_iam_member" "artifacts_storage_sa" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.storage.email}"
}

# `croquito-hml-rounds` saiu com o modo hospedado (ver acima). O bucket guardava a rodada
# montada por FUSE, e em 2026-08-18 verificou-se que ele **já não existe no projeto** (404) —
# foi removido por ato humano junto com o serviço. Tirá-lo daqui é reconciliação: o refresh
# nota a ausência e o state para de declarar um recurso que o mundo não tem. A rodada que
# estivesse nele não foi migrada por ninguém, por decisão registrada, e permanece
# reproduzível pelo CLI.

# ---------------------------------------------------------------------------
# Pub/Sub: tópico de processamento, DLQ e push subscription para o worker.
# ---------------------------------------------------------------------------

resource "google_pubsub_topic" "processing" {
  name = "croquito-hml-processing"
}

resource "google_pubsub_topic" "processing_dlq" {
  name = "croquito-hml-processing-dlq"
}

resource "google_pubsub_subscription" "processing_push" {
  name  = "croquito-hml-processing-push"
  topic = google_pubsub_topic.processing.id

  # Teto do Pub/Sub; etapas mais longas que isso reentregam — os handlers do
  # worker são idempotentes por comando.
  ack_deadline_seconds = 600

  push_config {
    push_endpoint = "${module.worker.url}/pubsub"

    oidc_token {
      service_account_email = google_service_account.push.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.processing_dlq.id
    max_delivery_attempts = 5
  }

  expiration_policy {
    ttl = "" # nunca expira por inatividade
  }

  # O Pub/Sub valida o actAs da SA de push na CRIAÇÃO da subscription.
  depends_on = [google_service_account_iam_member.infra_deploy_actas]
}

# Sub de leitura da DLQ (inspeção manual; sem consumidor automático em hml).
resource "google_pubsub_subscription" "dlq_inspecao" {
  name  = "croquito-hml-processing-dlq-inspecao"
  topic = google_pubsub_topic.processing_dlq.id

  ack_deadline_seconds = 60

  expiration_policy {
    ttl = ""
  }
}

# A API publica os comandos de processamento.
resource "google_pubsub_topic_iam_member" "processing_publisher_api" {
  topic  = google_pubsub_topic.processing.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.api.email}"
}

# O agente de serviço do Pub/Sub precisa cunhar o OIDC token da SA de push e
# mover mensagens esgotadas para a DLQ.
resource "google_service_account_iam_member" "pubsub_agent_token_creator" {
  service_account_id = google_service_account.push.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.pubsub_agent
}

resource "google_pubsub_topic_iam_member" "dlq_publisher_agent" {
  topic  = google_pubsub_topic.processing_dlq.id
  role   = "roles/pubsub.publisher"
  member = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "processing_subscriber_agent" {
  subscription = google_pubsub_subscription.processing_push.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

# ---------------------------------------------------------------------------
# Chave HMAC do interop S3. O par (access_id, secret) é o que a API e o worker
# usam para assinar URL de artefato — o GCS só devolve o segredo na criação, e é
# por isso que a chave precisa nascer aqui: importar uma chave criada fora
# traria o `secret` vazio, e o secret gravado seria mentira.
# ---------------------------------------------------------------------------

#
# A chave anterior, criada fora do Terraform, **continua válida** depois deste
# apply: são duas chaves ativas até alguém desativar a primeira. Ela não pode ser
# adotada (o segredo não é recuperável) nem desativada às cegas — desativar antes
# de o CI do croquito publicar a revisão que lê o secret novo derruba o upload de
# artefato, porque a revisão em execução ainda assina com a chave velha. A ordem é:
# apply aqui, deploy do croquito, e só então desativar a antiga pelo access_id que
# a versão desabilitada de `croquito-hml-storage-hmac-id` ainda guarda.
resource "google_storage_hmac_key" "storage" {
  service_account_email = google_service_account.storage.email
}

# ---------------------------------------------------------------------------
# Neon: o PostgreSQL gerenciado de hml.
#
# Este stack **não cria, não rotaciona e não apaga nada** no Neon: ele LÊ o
# projeto e propaga a credencial corrente para o Secret Manager. É de propósito.
# O incidente de 2026-08-14 não foi uma senha fraca nem uma política de expiração
# — foi a credencial do banco divergir do que o ambiente guardava, sem que nada
# reconciliasse as duas pontas. Reconciliar é exatamente o que um `data` faz, e
# fazê-lo sem poder de escrita mantém o raio de ação deste stack longe do banco.
#
# API/worker falam psycopg; o Keycloak fala JDBC e vive no schema `keycloak` do
# mesmo banco, com usuário e senha em secrets próprios — a forma dos dois DSNs
# veio dos secrets em uso, conferida em 2026-08-18.
# ---------------------------------------------------------------------------

# A branch é declarada por NOME, e o host vem do endpoint dela. Ninguém escreve
# hostname de banco à mão aqui — foi um hostname à mão que quebrou o ambiente:
# os secrets apontavam para `ep-still-firefly-audokk6w`, endpoint que não existe
# mais em nenhum projeto desta conta, e o proxy do Neon responde a endpoint
# desconhecido com falha de autenticação. Por isso o log dizia "password
# authentication failed" com a senha certa.
data "neon_branches" "hml" {
  project_id = var.neon_project_id
}

locals {
  branch = one([for b in data.neon_branches.hml.branches : b if b.name == var.neon_branch])
}

data "neon_branch_endpoints" "hml" {
  project_id = var.neon_project_id
  branch_id  = local.branch.id

  lifecycle {
    precondition {
      condition     = local.branch != null
      error_message = "Branch '${var.neon_branch}' não existe no projeto Neon ${var.neon_project_id}."
    }
  }
}

data "neon_branch_role_password" "hml" {
  project_id = var.neon_project_id
  branch_id  = local.branch.id
  role_name  = var.neon_role
}

locals {
  # `one()` porque a branch tem exatamente um endpoint de escrita: se um dia tiver
  # dois, é melhor o plano parar do que sortear qual deles o ambiente usa.
  neon_host = one([
    for e in data.neon_branch_endpoints.hml.endpoints : e.host if e.type == "read_write"
  ])

  neon_senha = data.neon_branch_role_password.hml.password

  # `urlencode` na senha: ela vai no userinfo da URL, e um caractere especial não
  # escapado transforma credencial válida em erro de parsing difícil de ler.
  #
  # `options=-csearch_path%3D<schema>` sem `public` na lista, de propósito: schema único no
  # `search_path` faz `current_schema()` virar NULL quando ele não existe, e o job de banco
  # recusa criar tabela em vez de recriá-las caladamente em `public`. Com `,public` no fim,
  # um schema ausente cairia de volta para lá — que é como as duas metades do banco foram
  # parar no mesmo lugar. `%3D` porque o `=` viaja dentro de um valor de query string.
  croquito_database_url = join("", [
    "postgresql+psycopg://${var.neon_role}:${urlencode(local.neon_senha)}",
    "@${local.neon_host}/${var.neon_database}?sslmode=require&channel_binding=require",
    "&options=-csearch_path%3D${var.croquito_schema}",
  ])

  # `currentSchema` aqui vale para a sessão JDBC; quem decide onde o Liquibase do Keycloak
  # cria tabela é `KC_DB_SCHEMA`, no deploy (`.github/workflows/deploy-hml.yml` do croquito).
  # Os dois precisam apontar para o mesmo schema — este DSN sozinho não move o DDL.
  keycloak_jdbc_url = "jdbc:postgresql://${local.neon_host}/${var.neon_database}?sslmode=require&currentSchema=${var.keycloak_schema}"
}

# ---------------------------------------------------------------------------
# Secret Manager.
# ---------------------------------------------------------------------------

module "secrets" {
  source  = "../../../modules/secret-manager"
  project = var.project

  # secret -> SAs de runtime que podem lê-lo.
  secrets = {
    "croquito-hml-database-url" = {
      acessores = [
        google_service_account.api.email,
        google_service_account.worker.email,
      ]
    }
    "croquito-hml-storage-hmac-id" = {
      acessores = [
        google_service_account.api.email,
        google_service_account.worker.email,
      ]
    }
    "croquito-hml-storage-hmac-secret" = {
      acessores = [
        google_service_account.api.email,
        google_service_account.worker.email,
      ]
    }
    "croquito-hml-kc-db-url"      = { acessores = [google_service_account.auth.email] }
    "croquito-hml-kc-db-user"     = { acessores = [google_service_account.auth.email] }
    "croquito-hml-kc-db-password" = { acessores = [google_service_account.auth.email] }
    "croquito-hml-kc-bootstrap-admin-password" = {
      acessores = [google_service_account.auth.email]
    }

    # Chaves de terceiro (OpenAI, Anthropic) para a suite de providers reais da
    # F-009. O valor NÃO nasce de um data source do Terraform (é chave de outro
    # fornecedor) nem entra por `gcloud secrets versions add`: a coordenada de
    # segredo que só um humano lembra de atualizar foi exatamente o defeito do
    # incidente do ADR-0031 (endpoint do Neon desatualizado, quatro dias fora do
    # ar). O caminho aqui é o mesmo espírito do ADR-0031 D1 — propagar é a
    # esteira, não um comando avulso —, mas write-only (`valores_wo` abaixo):
    # a chave chega por `TF_VAR_*` a partir de um GitHub Actions secret
    # (`.github/workflows/plan.yml`/`apply.yml`, mesmo padrão do `NEON_API_KEY`)
    # e nunca é gravada no state, porque, ao contrário da senha do Neon e da
    # chave HMAC, ela não nasce de um recurso deste Terraform — não há razão
    # para o state passar a guardá-la. Só a SA do worker lê: é o único lugar que
    # chama os providers reais (`build_real_provider_suite`).
    "croquito-hml-openai-api-key" = {
      acessores = [google_service_account.worker.email]
    }
    "croquito-hml-anthropic-api-key" = {
      acessores = [google_service_account.worker.email]
    }
  }

  # `KC_BOOTSTRAP_ADMIN_PASSWORD` fica fora deste mapa de propósito: ele só age na
  # criação do primeiro admin, então gerar um valor novo aqui não mudaria a senha
  # do admin que já existe no realm — só faria o secret divergir do mundo. Fica
  # como casca, e a troca dessa senha é ato no console do Keycloak.
  valores = {
    "croquito-hml-storage-hmac-id"     = google_storage_hmac_key.storage.access_id
    "croquito-hml-storage-hmac-secret" = google_storage_hmac_key.storage.secret
    "croquito-hml-database-url"        = local.croquito_database_url
    "croquito-hml-kc-db-url"           = local.keycloak_jdbc_url
    "croquito-hml-kc-db-user"          = var.neon_role
    "croquito-hml-kc-db-password"      = local.neon_senha
  }

  # Write-only: chave de terceiro que chega por `TF_VAR_*` (GitHub Actions
  # secret), nunca gravada no state. Sem default nas variáveis correspondentes
  # (ver variables.tf) — plan/apply falham fail-closed se a env não existir, em
  # vez de gravar secret vazio silenciosamente.
  valores_wo = {
    "croquito-hml-openai-api-key"    = var.openai_api_key
    "croquito-hml-anthropic-api-key" = var.anthropic_api_key
  }
  valores_wo_versions = {
    "croquito-hml-openai-api-key"    = var.providers_api_key_version
    "croquito-hml-anthropic-api-key" = var.providers_api_key_version
  }
}

# As cascas e os bindings nasceram neste stack antes de existir o módulo. Sem
# estes dois blocos o plano destrói e recria os sete secrets — e serviço sem
# credencial é exatamente o incidente que este stack está consertando. `moved`
# sem índice move todas as instâncias do `for_each` preservando as chaves, que
# são idênticas nos dois lados.
moved {
  from = google_secret_manager_secret.este
  to   = module.secrets.google_secret_manager_secret.este
}

moved {
  from = google_secret_manager_secret_iam_member.acesso
  to   = module.secrets.google_secret_manager_secret_iam_member.acesso
}

# ---------------------------------------------------------------------------
# DNS privado da VPC para run.app: sem ele, o egress VPC do proxy resolve os
# hosts *.run.app para os IPs públicos do Google Frontend e o ingress interno
# dos backends classifica a requisição como EXTERNA (404). A zona faz a VPC
# resolver run.app para a faixa do private.googleapis.com, cujo caminho é
# reconhecido como interno. Requisito documentado de "ingress interno a partir
# de VPC"; vale para a VPC inteira, e mora aqui porque o croquito é quem o
# exige hoje.
# ---------------------------------------------------------------------------

resource "google_dns_managed_zone" "run_app_privada" {
  name        = "run-app-privada"
  dns_name    = "run.app."
  description = "Resolve run.app para private.googleapis.com dentro da VPC hml (ingress interno)."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${var.vpc_network}"
    }
  }
}

resource "google_dns_record_set" "run_app_apex" {
  managed_zone = google_dns_managed_zone.run_app_privada.name
  name         = "run.app."
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
}

resource "google_dns_record_set" "run_app_wildcard" {
  managed_zone = google_dns_managed_zone.run_app_privada.name
  name         = "*.run.app."
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
}
