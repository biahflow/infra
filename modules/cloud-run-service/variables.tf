variable "nome" {
  description = "Nome do serviço Cloud Run."
  type        = string
}

variable "project" {
  description = "Projeto GCP onde o serviço é publicado."
  type        = string
}

variable "region" {
  description = "Região do serviço."
  type        = string
}

variable "image_inicial" {
  description = <<-EOT
    Imagem usada apenas na criação do serviço. Depois disso a revisão é do CI da
    aplicação: mudar este valor não redeploya nada (ver `lifecycle` em main.tf).
  EOT
  type        = string
}

variable "min_instances" {
  description = "Instâncias mínimas (0 = escala a zero, com cold start)."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Teto de instâncias — limite de custo tanto quanto de capacidade."
  type        = number
  default     = 3
}

variable "publico" {
  description = "Concede `roles/run.invoker` a `allUsers` (serviço aberto na internet)."
  type        = bool
  default     = true
}
