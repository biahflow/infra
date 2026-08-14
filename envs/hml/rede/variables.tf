variable "project" {
  description = "Projeto GCP de homologação."
  type        = string
  default     = "biahflow-hml"
}

variable "region" {
  description = "Região do router/NAT."
  type        = string
  default     = "us-east1"
}
