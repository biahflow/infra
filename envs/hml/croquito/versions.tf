terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    # Provider de terceiro, ainda em 0.x: a faixa é apertada de propósito, porque
    # 0.x não promete compatibilidade entre menores e este stack lê a credencial
    # do banco por ele.
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.15.0"
    }
  }

  backend "gcs" {
    bucket = "biahflow-hml-tfstate"
    prefix = "envs/hml/croquito"
  }
}
