# Serviços Cloud Run de homologação.
#
# `eliseu-hml` substitui o `oikos-proto-web`, que foi criado à mão e continua no
# ar até o domain mapping de `envs/hml/eliseu-demo` apontar para cá. O serviço
# antigo não é importado: some quando ninguém mais o endereçar.

provider "google" {
  project = var.project
  region  = var.region
}

module "eliseu" {
  source = "../../../modules/cloud-run-service"

  nome          = "eliseu-hml"
  project       = var.project
  region        = var.region
  image_inicial = var.eliseu_image_inicial

  # Homologação escala a zero; o teto existe para conter custo de rajada.
  min_instances = 0
  max_instances = 3
  publico       = true
}
