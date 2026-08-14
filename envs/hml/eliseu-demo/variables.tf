variable "cloudflare_zone" {
  description = "Zona Cloudflare onde o subdomínio de demo é criado."
  type        = string
  default     = "biahflow.ai"
}

variable "subdominio" {
  description = "Subdomínio do demo, sem o sufixo da zona."
  type        = string
  default     = "eliseu-demo"
}

variable "gcp_project" {
  description = "Projeto GCP (namespace) onde o Cloud Run do demo está publicado."
  type        = string
  default     = "biahflow-hml"
}

variable "regiao" {
  description = "Região do Cloud Run do demo."
  type        = string
  default     = "us-east1"
}

variable "servico" {
  description = "Nome do serviço Cloud Run que recebe o domain mapping."
  type        = string
  # Era "oikos-proto-web", o serviço criado à mão. Passa a apontar para o
  # `eliseu-hml` de `envs/hml/servicos`. `spec.route_name` não é atualizável no
  # lugar: o apply substitui o domain mapping, com uma janela curta de
  # indisponibilidade do hostname enquanto o certificado é reemitido.
  default = "eliseu-hml"
}
