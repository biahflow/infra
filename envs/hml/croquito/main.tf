# Homologação do croquito: cinco serviços Cloud Run com um único host público.
#
# Só o `croquito-web-hml` (nginx: dois SPAs + proxy same-origin) aceita tráfego
# da internet; API, medição e Keycloak têm ingress interno e só são alcançados
# pelo proxy, via Direct VPC egress. O worker é interno e privado: quem o invoca
# é a push subscription do Pub/Sub, com OIDC token da SA dedicada.
#
# O que este stack NÃO faz, de propósito:
#   - valores de secret (as cascas nascem aqui; versões entram por `gcloud
#     secrets versions add`, nunca por Terraform nem por CI do GitHub);
#   - chave HMAC do interop S3 (criada fora do TF para o segredo não morar no
#     state; a SA dona dela nasce aqui);
#   - env/imagem/volumes dos serviços (CI do biahflow/croquito é o dono — ver
#     lifecycle do módulo cloud-run-service).

provider "google" {
  project = var.project
  region  = var.region
}

data "google_project" "este" {
  project_id = var.project
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.este.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
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

resource "google_service_account" "medicao" {
  account_id   = "croquito-medicao-hml"
  display_name = "Runtime do servidor de medição do croquito em hml"
}

resource "google_service_account" "auth" {
  account_id   = "croquito-auth-hml"
  display_name = "Runtime do Keycloak do croquito em hml"
}

# Dona da chave HMAC do interop S3 (a chave em si é criada fora do TF).
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
    web     = google_service_account.web
    api     = google_service_account.api
    worker  = google_service_account.worker
    medicao = google_service_account.medicao
    auth    = google_service_account.auth
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

  nome            = "croquito-api-hml"
  project         = var.project
  region          = var.region
  image_inicial   = var.image_inicial
  service_account = google_service_account.api.email

  # Ingress ALL por contingência (2026-08-14): o caminho interno da API é
  # recusado pelo GFE com 404 mesmo com casca idêntica à do auth e da medição
  # (bug de plataforma; hello roteia, workload real não — thread aberto no
  # fórum do Google). A barreira volta a ser a autenticação da aplicação (JWT
  # fail-closed). Reverter a INTERNAL_ONLY quando o bug for corrigido.
  publico = true
  ingress = "INGRESS_TRAFFIC_ALL"

  min_instances = 0
  max_instances = 3

  depends_on = [google_service_account_iam_member.infra_deploy_actas]
}

module "worker" {
  source = "../../../modules/cloud-run-service"

  nome            = "croquito-worker-hml"
  project         = var.project
  region          = var.region
  image_inicial   = var.image_inicial
  service_account = google_service_account.worker.email

  # Mesma contingência da API (bug do caminho interno); o worker continua
  # PRIVADO por IAM — só a SA do push do Pub/Sub tem run.invoker.
  publico = false
  ingress = "INGRESS_TRAFFIC_ALL"

  min_instances = 0
  max_instances = 3

  depends_on = [google_service_account_iam_member.infra_deploy_actas]
}

module "medicao" {
  source = "../../../modules/cloud-run-service"

  nome            = "croquito-medicao-hml"
  project         = var.project
  region          = var.region
  image_inicial   = var.image_inicial
  service_account = google_service_account.medicao.email

  publico = true
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  # Locks de rodada em memória do servidor de medição: uma instância só.
  min_instances = 0
  max_instances = 1

  depends_on = [google_service_account_iam_member.infra_deploy_actas]
}

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

  depends_on = [google_service_account_iam_member.infra_deploy_actas]
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
}

resource "google_storage_bucket" "rounds" {
  name     = "croquito-hml-rounds"
  location = upper(var.region)

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

# API e worker acessam artefatos com a HMAC da SA de storage; a permissão da
# chave é a permissão da SA.
resource "google_storage_bucket_iam_member" "artifacts_storage_sa" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.storage.email}"
}

# O servidor de medição monta o bucket de rodadas por GCS FUSE com a própria
# runtime SA.
resource "google_storage_bucket_iam_member" "rounds_medicao" {
  bucket = google_storage_bucket.rounds.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.medicao.email}"
}

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
# Secret Manager: cascas. Valores entram por `gcloud secrets versions add`.
# ---------------------------------------------------------------------------

locals {
  # secret -> SAs de runtime que podem lê-lo.
  secrets = {
    "croquito-hml-database-url" = [
      google_service_account.api.email,
      google_service_account.worker.email,
    ]
    "croquito-hml-storage-hmac-id" = [
      google_service_account.api.email,
      google_service_account.worker.email,
    ]
    "croquito-hml-storage-hmac-secret" = [
      google_service_account.api.email,
      google_service_account.worker.email,
    ]
    "croquito-hml-kc-db-url"      = [google_service_account.auth.email]
    "croquito-hml-kc-db-user"     = [google_service_account.auth.email]
    "croquito-hml-kc-db-password" = [google_service_account.auth.email]
    "croquito-hml-kc-bootstrap-admin-password" = [
      google_service_account.auth.email,
    ]
  }

  secret_bindings = merge([
    for secret, emails in local.secrets : {
      for email in emails : "${secret}|${email}" => { secret = secret, email = email }
    }
  ]...)
}

resource "google_secret_manager_secret" "este" {
  for_each = local.secrets

  secret_id = each.key

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "acesso" {
  for_each = local.secret_bindings

  secret_id = google_secret_manager_secret.este[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.email}"
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
