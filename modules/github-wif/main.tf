# Federação de identidade entre GitHub Actions e um projeto GCP: pool + provider
# OIDC (quem pode entrar) e uma service account de deploy (o que se pode fazer
# depois de entrar). Sem chave de service account em lugar nenhum.

data "google_project" "this" {
  project_id = var.project
}

resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project
  workload_identity_pool_id = var.pool_id
}

resource "google_iam_workload_identity_pool_provider" "this" {
  project                            = var.project
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # jsonencode gera exatamente `["a","b"]`, o mesmo formato já aplicado no
  # provider vivo — evita diff cosmético a cada mudança da lista.
  attribute_condition = "attribute.repository in ${jsonencode(var.repos_allowlist)}"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deploy" {
  project    = var.project
  account_id = var.deploy_sa_id
}

# Binding autoritativo: a lista de repositórios aqui é a verdade sobre quem pode
# impersonar a SA de deploy. Fica condicional porque um binding autoritativo com
# `members = []` é aceito pelo Terraform mas rejeitado pela API do IAM; sem
# repositórios, o certo é não existir binding nenhum.
resource "google_service_account_iam_binding" "deploy" {
  count = length(var.deploy_sa_repos) > 0 ? 1 : 0

  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    for repo in var.deploy_sa_repos :
    "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.this.workload_identity_pool_id}/attribute.repository/${repo}"
  ]
}
