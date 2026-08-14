# Módulo `cloud-run-service`

Casca de serviço Cloud Run v2 com escala e exposição controladas pelo
Terraform, e revisão controlada pelo CI da aplicação.

## Divisão de propriedade

| Quem | É dono de |
| --- | --- |
| Terraform (este módulo) | existência do serviço, região, ingress, VPC egress, min/max instâncias, `roles/run.invoker` |
| CI da aplicação | imagem, revisão, labels, env, command/args, recursos, volumes, service account, timeout, concorrência, tráfego |

O `lifecycle.ignore_changes` em `main.tf` materializa essa divisão: `client`,
`client_version` e, dentro do template, `containers[0].{image,env,command,args,
resources,volume_mounts,ports}`, `volumes`, `service_account`, `timeout`,
`max_instance_request_concurrency` e `labels` — tudo que um
`gcloud run services update` de deploy de aplicação escreve. `var.image_inicial`
só vale na criação — trocar o valor depois não redeploya nada.

**Manutenção da lista:** se um `terraform plan` logo depois de um deploy do CI
acusar drift num campo que o módulo não declara, o campo é do CI. Acrescente-o
ao `ignore_changes` e registre aqui. Campos com chance de aparecer:
`template[0].revision` (quando o CI nomeia revisões), `template[0].annotations`
e `traffic` (se o CI fizer split).

## Notas

- `deletion_protection` fica no default do provider (`true`): destruir o
  serviço exige desligar a proteção conscientemente.
- `publico = true` publica o serviço para `allUsers`. Serviço interno deve
  passar `publico = false` e ganhar seu próprio binding de invoker.
