# Módulo `secret-manager`

Secrets do Secret Manager como dado de um mapa: casca, quem lê e — quando o
Terraform é dono dele — o valor corrente.

## Divisão de propriedade

| Quem | É dono de |
| --- | --- |
| Terraform (este módulo) | existência do secret, replicação, `roles/secretmanager.secretAccessor` por leitor, versão corrente dos secrets citados em `valores` ou `valores_wo` |
| Quem produz o valor | o valor em si — outro recurso do Terraform (chave HMAC, senha de role), um secret de CI passado por `TF_VAR_*` (caminho `valores_wo`), ou, para secret fora dos dois mapas, um caminho declarado no stack |

Secret sem entrada em `valores` nem em `valores_wo` nasce e permanece **casca**:
existe, tem IAM, e nenhuma versão. É o estado correto para valor que o Terraform
não produz e não deve inventar. Um secret usa `valores` OU `valores_wo`, nunca
os dois (validado nas variáveis).

## Uso

```hcl
module "secrets" {
  source  = "../../../modules/secret-manager"
  project = var.project

  secrets = {
    "app-db-url"    = { acessores = [google_service_account.api.email] }
    "admin-inicial" = { acessores = [google_service_account.auth.email] }
  }

  valores = {
    "app-db-url" = "postgresql://…"
  }
  # "admin-inicial" fica como casca: sem versão.
}
```

## O valor fica no state

`secret_data` é argumento comum: o provider precisa dele para saber que o valor
mudou, e portanto ele é persistido no state.

Isso é aceitável neste repositório porque os valores que o Terraform governa aqui
**nascem de outros recursos do próprio Terraform** — `google_storage_hmac_key.secret`
e a senha de uma role de banco são `computed` e `sensitive`, ou seja, já estão no
state pela origem. Passar por este módulo não piora o que já é verdade. O que
segue valendo, e é o que torna a decisão sustentável: o state mora em bucket
privado e versionado, e quem lê o state lê os segredos.

**Para valor que venha de fora do Terraform o caminho é `valores_wo`.** O
provider 6.x tem `secret_data_wo` (write-only): o valor vai para a API e não é
gravado no state. Como o provider não guarda esse valor para comparar, ele
sozinho não percebe rotação — por isso toda chave em `valores_wo` exige uma
entrada correspondente em `valores_wo_versions`, e é esse número
(`secret_data_wo_version`) que aciona a troca, não o texto do segredo.

```hcl
module "secrets" {
  source  = "../../../modules/secret-manager"
  project = var.project

  secrets = {
    "provider-api-key" = { acessores = [google_service_account.worker.email] }
  }

  valores_wo = {
    "provider-api-key" = var.provider_api_key # ex.: TF_VAR_provider_api_key, de um secret do CI
  }
  valores_wo_versions = {
    "provider-api-key" = 1 # incrementar para rotacionar
  }
}
```

## Rotação

Mudar um valor em `valores` substitui a versão. Duas escolhas tornam a troca
segura, e as duas estão em `main.tf` (e valem também para `valores_wo` —
`corrente_wo` usa o mesmo par):

- `create_before_destroy`: a versão nova nasce antes de a antiga sair, então não
  existe instante em que `latest` não resolve;
- `deletion_policy = "DISABLE"`: a versão anterior é desabilitada, não destruída
   — voltar atrás é reabilitar algo que ainda existe, não recuperar um valor
   perdido.

Serviço do Cloud Run que monta o secret por `:latest` só relê no **próximo
deploy**: rotacionar aqui não reinicia ninguém, e a revisão em execução segue com
o valor antigo até o CI da aplicação publicar de novo. Isso é ordem de operação,
não defeito — mas precisa ser respeitado quando a rotação é o conserto de uma
credencial quebrada.

## Notas

- O nome do secret não é segredo; o valor é. Por isso `for_each` percorre
  `nonsensitive(keys(var.valores))` (e o mesmo para `valores_wo`) — sem isso o
  Terraform recusa o `for_each`, e nenhum valor passa por essa expressão.
- `acessores` é a resposta inteira para "quem lê este segredo". Um binding feito
  fora do módulo não aparece aqui e será removido no próximo apply.
- Write-only exige Terraform >= 1.11 no executor (recurso de linguagem, não só do
  provider). Os stacks deste repositório já pinam 1.14.3 no CI.
