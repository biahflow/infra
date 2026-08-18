variable "project" {
  description = "Projeto GCP onde os secrets vivem."
  type        = string
}

variable "secrets" {
  description = <<-EOT
    Secrets a manter, por nome. `acessores` são e-mails de service account que
    recebem `roles/secretmanager.secretAccessor` naquele secret — a lista é a
    resposta inteira para "quem lê este segredo", e um e-mail fora dela não lê.
  EOT

  type = map(object({
    acessores = optional(list(string), [])
  }))
}

variable "valores" {
  description = <<-EOT
    Valor corrente por secret, quando o Terraform é dono dele. A chave é o nome
    do secret e precisa existir em `var.secrets`; secret ausente deste mapa nasce
    como casca, sem nenhuma versão, e seu valor entra por outro caminho.

    Mudar um valor aqui cria uma versão nova e desabilita a anterior.
  EOT

  type      = map(string)
  sensitive = true
  default   = {}

  validation {
    condition     = alltrue([for nome in keys(var.valores) : contains(keys(var.secrets), nome)])
    error_message = "Todo secret citado em `valores` precisa estar declarado em `secrets`."
  }
}
