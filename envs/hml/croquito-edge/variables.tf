variable "cloudflare_zone" {
  description = "Zona DNS na Cloudflare."
  type        = string
  default     = "biahflow.ai"
}

variable "subdominio" {
  description = "Subdomínio público da interface unificada do croquito em hml."
  type        = string
  default     = "croquito-hml"
}

variable "origem" {
  description = <<-EOT
    Hostname run.app do serviço croquito-web-hml, na forma determinística
    `<serviço>-<número do projeto>.<região>.run.app`. Construído e não lido do
    serviço para não amarrar este stack ao state de envs/hml/croquito.
  EOT
  type        = string
  default     = "croquito-web-hml-209400815796.us-east1.run.app"
}
