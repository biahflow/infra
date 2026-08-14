# Casca de um serviço Cloud Run v2: o Terraform é dono da existência do serviço
# e da configuração estável (região, ingress, escala, quem pode invocar); o CI da
# aplicação é dono da revisão e da imagem.

resource "google_cloud_run_v2_service" "this" {
  name     = var.nome
  project  = var.project
  location = var.region

  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image_inicial
    }
  }

  # Fronteira de propriedade com o CI da aplicação. `client`/`client_version` são
  # carimbados por quem fez o último deploy (gcloud, Actions); imagem e labels da
  # revisão mudam a cada deploy. Se um plan depois de um deploy acusar drift em
  # outro campo, é sinal de que o campo também é do CI: acrescente-o aqui e
  # registre no README do módulo.
  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
      template[0].labels,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "publico" {
  count = var.publico ? 1 : 0

  project  = google_cloud_run_v2_service.this.project
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
