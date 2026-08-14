# Casca de um serviço Cloud Run v2: o Terraform é dono da existência do serviço
# e da configuração estável (região, ingress, rede, escala, quem pode invocar); o
# CI da aplicação é dono da revisão e da imagem.

resource "google_cloud_run_v2_service" "this" {
  name     = var.nome
  project  = var.project
  location = var.region

  ingress = var.ingress

  template {
    # Runtime SA declarada na criação: sem ela o Cloud Run cai na SA default de
    # compute, que a infra-deploy (corretamente) não pode impersonar. Depois da
    # criação o campo é do CI (ignore_changes abaixo).
    service_account = var.service_account

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image_inicial
    }

    # Direct VPC egress: com ALL_TRAFFIC, chamadas a serviços internos do mesmo
    # projeto entram como tráfego interno — é o que permite um serviço público
    # fazer proxy para serviços com ingress interno. Exige Private Google Access
    # na subnet (habilitado em hml-us-east1).
    dynamic "vpc_access" {
      for_each = var.vpc_network == null ? [] : [var.vpc_network]

      content {
        egress = "ALL_TRAFFIC"

        network_interfaces {
          network    = var.vpc_network
          subnetwork = var.vpc_subnet
        }
      }
    }
  }

  # Fronteira de propriedade com o CI da aplicação. `client`/`client_version` são
  # carimbados por quem fez o último deploy (gcloud, Actions); imagem, labels,
  # env, command/args, recursos, volumes, service account, timeout e concorrência
  # da revisão mudam a cada deploy da aplicação. Se um plan depois de um deploy
  # acusar drift em outro campo, é sinal de que o campo também é do CI:
  # acrescente-o aqui e registre no README do módulo.
  lifecycle {
    ignore_changes = [
      client,
      client_version,
      # Bloco de scaling de NÍVEL DE SERVIÇO (não o do template): o gcloud de
      # deploy o materializa no serviço vivo; sem ignorá-lo, todo plan tenta um
      # update in-place — que exige actAs na runtime SA do serviço alheio.
      scaling,
      template[0].containers[0].image,
      template[0].containers[0].env,
      template[0].containers[0].command,
      template[0].containers[0].args,
      template[0].containers[0].resources,
      template[0].containers[0].volume_mounts,
      template[0].containers[0].ports,
      template[0].volumes,
      template[0].service_account,
      template[0].timeout,
      template[0].max_instance_request_concurrency,
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
