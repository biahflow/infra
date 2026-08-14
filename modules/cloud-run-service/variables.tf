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

variable "ingress" {
  description = <<-EOT
    Política de ingress do serviço. `INGRESS_TRAFFIC_INTERNAL_ONLY` deixa o
    serviço inalcançável da internet — só tráfego interno do projeto (VPC via
    Direct VPC egress, Pub/Sub push, Eventarc) chega nele.
  EOT
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.ingress)
    error_message = "ingress deve ser um dos valores INGRESS_TRAFFIC_* do Cloud Run v2."
  }
}

variable "vpc_network" {
  description = <<-EOT
    Nome da VPC para Direct VPC egress (com `ALL_TRAFFIC`). Null = sem VPC
    egress. Usado por serviços que precisam alcançar serviços de ingress
    interno (ex.: um proxy público na frente de backends internos).
  EOT
  type        = string
  default     = null
}

variable "vpc_subnet" {
  description = "Subnet do Direct VPC egress (obrigatória quando vpc_network é definido)."
  type        = string
  default     = null
}

variable "service_account" {
  description = <<-EOT
    E-mail da runtime service account com que o serviço NASCE. Null usa a SA
    default de compute — evite: exige actAs nela para quem aplica. Depois da
    criação o campo é do CI da aplicação (ignore_changes).
  EOT
  type        = string
  default     = null
}
