terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52"
    }
  }

  backend "gcs" {
    bucket = "biahflow-hml-tfstate"
    prefix = "envs/hml/croquito-edge"
  }
}
