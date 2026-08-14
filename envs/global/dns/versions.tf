terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52"
    }
  }

  # Stack global, mas o estado mora no bucket de hml: é o único projeto com
  # bucket de state hoje e o conteúdo aqui não é sensível a ambiente.
  backend "gcs" {
    bucket = "biahflow-hml-tfstate"
    prefix = "envs/global/dns"
  }
}
