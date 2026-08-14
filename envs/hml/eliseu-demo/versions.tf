terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Migrado do estado local de `plataforma-oikos/ops/terraform` para o bucket
  # compartilhado. Os endereços dos recursos foram preservados justamente para
  # que o estado antigo possa ser migrado sem recriar nada.
  backend "gcs" {
    bucket = "biahflow-hml-tfstate"
    prefix = "envs/hml/eliseu-demo"
  }
}
