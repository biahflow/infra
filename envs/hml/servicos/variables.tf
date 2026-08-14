variable "project" {
  description = "Projeto GCP de homologação."
  type        = string
  default     = "biahflow-hml"
}

variable "region" {
  description = "Região dos serviços de homologação."
  type        = string
  default     = "us-east1"
}

variable "eliseu_image_inicial" {
  description = <<-EOT
    Imagem com que o serviço `eliseu-hml` nasce. Só vale na criação: a partir do
    primeiro deploy, a revisão é do CI da aplicação.
  EOT
  type        = string
  default     = "us-east1-docker.pkg.dev/biahflow-hml/hml/oikos-proto-web:776eeef975987dd05bd32ed42df535f9674217d5"
}
