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

variable "valores_wo" {
  description = <<-EOT
    Valor corrente por secret, write-only (`secret_data_wo`): o valor vai para a
    API do Secret Manager e NÃO é gravado no state. É o caminho para valor que
    nasce fora do Terraform — chave de terceiro injetada por env em CI, por
    exemplo — ao contrário de `var.valores`, aceitável no state só porque os
    valores ali nascem de outros recursos do próprio Terraform.

    A chave precisa existir em `var.secrets` e não pode também estar em
    `var.valores` (um secret usa um caminho por vez). Como o provider não guarda
    o valor write-only para comparar, toda chave aqui precisa de uma entrada
    correspondente em `var.valores_wo_versions` — é esse número, não o texto do
    segredo, que aciona a rotação.

    Secret ausente de `var.valores` e `var.valores_wo` nasce como casca, sem
    nenhuma versão.
  EOT

  type      = map(string)
  sensitive = true
  default   = {}

  validation {
    condition     = alltrue([for nome in keys(var.valores_wo) : contains(keys(var.secrets), nome)])
    error_message = "Todo secret citado em `valores_wo` precisa estar declarado em `secrets`."
  }

  validation {
    condition = length(setintersection(
      toset(nonsensitive(keys(var.valores_wo))),
      toset(nonsensitive(keys(var.valores))),
    )) == 0
    error_message = "Um secret não pode estar em `valores` e `valores_wo` ao mesmo tempo — escolha um caminho por secret."
  }
}

variable "valores_wo_versions" {
  description = <<-EOT
    Gatilho de rotação dos secrets em `var.valores_wo`: como o write-only não
    fica no state, o provider não tem como perceber sozinho que o valor mudou —
    incrementar o número aqui é o sinal (`secret_data_wo_version`). Toda chave
    presente em `var.valores_wo` precisa de uma entrada correspondente aqui; sem
    ela, a primeira versão do secret nunca nasce.
  EOT

  type    = map(number)
  default = {}

  validation {
    condition     = alltrue([for nome in keys(var.valores_wo) : contains(keys(var.valores_wo_versions), nome)])
    error_message = "Todo secret em `valores_wo` precisa de uma entrada correspondente em `valores_wo_versions`."
  }
}
