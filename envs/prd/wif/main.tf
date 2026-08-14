# Identidade de CI em produção — espelho de `envs/hml/wif`, mas tudo novo: não
# há nada a importar em biahflow-prd.
#
# A SA `prd-deploy` nasce sem binding de workloadIdentityUser: criar a
# identidade é barato e reversível, dar acesso a ela não. O binding entra junto
# com a primeira aplicação em produção.

provider "google" {
  project = var.project
  region  = var.region
}

module "wif" {
  source = "../../../modules/github-wif"

  project         = var.project
  repos_allowlist = var.repos_allowlist
  deploy_sa_id    = "prd-deploy"
  deploy_sa_repos = var.deploy_sa_repos

  pool_display_name      = "GitHub Actions"
  provider_display_name  = "GitHub OIDC"
  deploy_sa_display_name = "Deploy de PRD pelo GitHub Actions"
}

resource "google_service_account" "infra_deploy" {
  project      = var.project
  account_id   = "infra-deploy"
  display_name = "CI do repositório de infraestrutura (prd)"
}

resource "google_service_account_iam_binding" "infra_deploy" {
  service_account_id = google_service_account.infra_deploy.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${module.wif.pool_name}/attribute.repository/${var.infra_repo}",
  ]
}

resource "google_project_iam_member" "infra_deploy" {
  for_each = toset(var.infra_deploy_roles)

  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.infra_deploy.email}"
}

# Bucket criado fora do Terraform (guarda o estado deste stack); aqui só o IAM.
# storage.admin ESCOPADO ao bucket: o CI precisa de setIamPolicy para aplicar
# este próprio recurso, e objectAdmin não concede.
resource "google_storage_bucket_iam_member" "infra_deploy_state" {
  bucket = var.state_bucket
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.infra_deploy.email}"
}
