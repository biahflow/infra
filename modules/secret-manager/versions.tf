terraform {
  # 1.9 pela validação de variável que referencia outra variável (`valores`
  # conferida contra `secrets`).
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
