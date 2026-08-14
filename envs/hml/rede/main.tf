# Rede de hml: adoção do router e do Cloud NAT que já existiam fora do
# Terraform (criados à mão junto com a VPC hml), pelo padrão do repositório —
# bloco import{}, nunca terraform import na mão.
#
# A adoção existe por causa de UMA mudança: o escopo do NAT deixa de ser "todas
# as subnets" e passa a listar explicitamente a hml-us-east1. Medido em
# 2026-08-14: o NAT SNATeava também o egress VPC dos serviços Cloud Run do
# croquito (IP de saída = hml-saida), e com origem SNATeada o ingress interno
# do Cloud Run classifica o tráfego como EXTERNO e recusa (404). A subnet nova
# do croquito (em envs/hml/croquito) fica FORA da lista: sem NAT, o caminho ao
# Google é o Private Google Access, que o Cloud Run reconhece como interno.
# Para quem está na hml-us-east1 (portal), nada muda — a lista preserva o
# comportamento que "todas as subnets" dava, porque ela era a única subnet.

provider "google" {
  project = var.project
  region  = var.region
}

import {
  to = google_compute_router.hml
  id = "projects/${var.project}/regions/${var.region}/routers/hml"
}

import {
  to = google_compute_router_nat.hml
  id = "${var.project}/${var.region}/hml/hml"
}

data "google_compute_subnetwork" "hml_us_east1" {
  name   = "hml-us-east1"
  region = var.region
}

data "google_compute_address" "hml_saida" {
  name   = "hml-saida"
  region = var.region
}

resource "google_compute_router" "hml" {
  name    = "hml"
  region  = var.region
  network = "hml"
}

resource "google_compute_router_nat" "hml" {
  name   = "hml"
  router = google_compute_router.hml.name
  region = var.region

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [data.google_compute_address.hml_saida.self_link]

  # A mudança que motivou a adoção: lista explícita no lugar de "todas".
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = data.google_compute_subnetwork.hml_us_east1.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  endpoint_types                      = ["ENDPOINT_TYPE_VM"]
  enable_endpoint_independent_mapping = false
}
