# Identidade de CI em homologação. Duas trilhas separadas de propósito:
#
#   hml-deploy   -> usada pelos repositórios de aplicação para publicar imagem
#                   e revisão; já existia e é importada.
#   infra-deploy -> usada por este repositório para aplicar Terraform; nova, com
#                   permissões de administração de IAM/Cloud Run e escrita no
#                   bucket de estado.
#
# Nenhuma das duas tem chave: o acesso vem do token OIDC do GitHub Actions.

provider "google" {
  project = var.project
  region  = var.region
}

module "wif" {
  source = "../../../modules/github-wif"

  project         = var.project
  repos_allowlist = var.repos_allowlist
  deploy_sa_id    = "hml-deploy"
  deploy_sa_repos = var.deploy_sa_repos
}

resource "google_service_account" "infra_deploy" {
  project      = var.project
  account_id   = "infra-deploy"
  display_name = "CI do repositório de infraestrutura (hml)"
}

resource "google_service_account_iam_binding" "infra_deploy" {
  service_account_id = google_service_account.infra_deploy.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${module.wif.pool_name}/attribute.repository/${var.infra_repo}",
  ]
}

# Permissões de projeto. `iam_member` (não `iam_binding`) para não assumir
# propriedade autoritativa dos papéis: outras identidades podem ter os mesmos
# papéis por motivos que este stack não conhece.
resource "google_project_iam_member" "infra_deploy" {
  for_each = toset(var.infra_deploy_roles)

  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.infra_deploy.email}"
}

# O bucket de estado é criado fora do Terraform (ovo e galinha: ele guarda o
# estado deste stack). Aqui só se concede acesso a ele.
resource "google_storage_bucket_iam_member" "infra_deploy_state" {
  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.infra_deploy.email}"
}
