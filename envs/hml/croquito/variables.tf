variable "project" {
  description = "Projeto GCP de homologação."
  type        = string
  default     = "biahflow-hml"
}

variable "region" {
  description = "Região dos serviços e buckets do croquito em hml."
  type        = string
  default     = "us-east1"
}

variable "host_publico" {
  description = <<-EOT
    Hostname público da interface unificada (borda Cloudflare em
    envs/hml/croquito-edge). Entra no CORS do bucket de artefatos — o presigned
    PUT/GET do browser fala direto com o GCS, único lugar onde CORS sobrevive ao
    desenho same-origin.
  EOT
  type        = string
  default     = "croquito-hml.biahflow.ai"
}

variable "vpc_network" {
  description = "VPC existente usada pelo Direct VPC egress do serviço web (proxy)."
  type        = string
  default     = "hml"
}

variable "vpc_subnet" {
  description = "Subnet us-east1 da VPC hml (Private Google Access habilitado)."
  type        = string
  default     = "hml-us-east1"
}

variable "image_inicial" {
  description = <<-EOT
    Imagem com que os serviços nascem. Só vale na criação: a partir do primeiro
    deploy, a revisão é do CI do repositório biahflow/croquito. O hello do Cloud
    Run existe para o serviço subir saudável antes da primeira imagem real.
  EOT
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}
