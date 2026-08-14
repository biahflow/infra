# infra

Terraform da biahflow: identidade de CI, serviços Cloud Run e DNS, em
`biahflow-hml` e `biahflow-prd`.

## Mapa

```
modules/
  github-wif/          pool + provider OIDC do GitHub + SA de deploy e seus bindings
  cloud-run-service/   casca de serviço Cloud Run v2 (o CI da app é dono da revisão)
envs/
  global/dns/          zona Cloudflare biahflow.ai (thin: só o zone_id e registros compartilhados)
  hml/wif/             identidade de CI em hml — importa o que já existia
  hml/servicos/        serviço eliseu-hml
  hml/eliseu-demo/     eliseu-demo.biahflow.ai (CNAME + domain mapping)
  prd/wif/             identidade de CI em prd — tudo novo
  prd/servicos/        scaffold, ainda sem conteúdo
.github/workflows/
  plan.yml             PR: plano dos stacks alterados no resumo do job
  apply.yml            push na main: apply em ordem fixa
```

Cada diretório de `envs/**` é um stack: um state, um `terraform init`. O prefixo
no bucket é sempre o caminho do stack (`envs/hml/wif` → prefix `envs/hml/wif`),
para que o mapa do repositório seja o mapa do bucket.

| Stack | State |
| --- | --- |
| `envs/global/dns` | `gs://biahflow-hml-tfstate/envs/global/dns` |
| `envs/hml/*` | `gs://biahflow-hml-tfstate/envs/hml/*` |
| `envs/prd/*` | `gs://biahflow-prd-tfstate/envs/prd/*` |

Os buckets de state existem fora do Terraform (com versionamento, em
`us-east1`): eles guardam o estado, então não podem depender dele.

## Rodando local

Credenciais:

```bash
gcloud auth application-default login          # GCP (ou GOOGLE_APPLICATION_CREDENTIALS)
export CLOUDFLARE_API_TOKEN=...                # Zone Read + DNS Edit em biahflow.ai
```

`CLOUDFLARE_API_TOKEN` só é necessário em `envs/global/dns` e
`envs/hml/eliseu-demo`.

```bash
terraform -chdir=envs/hml/wif init
terraform -chdir=envs/hml/wif plan
terraform -chdir=envs/hml/wif apply
```

Verificação sem tocar em nuvem nenhuma (não precisa de credencial):

```bash
terraform fmt -check -recursive
terraform -chdir=envs/hml/wif init -backend=false && terraform -chdir=envs/hml/wif validate
```

## Bootstrap

O CI não consegue rodar o primeiro apply: ele autentica com o provider OIDC que
o próprio `envs/hml/wif` cria. A ordem do bootstrap, local:

1. `envs/hml/wif` — adota o que já existe (ver imports abaixo) e cria a
   `infra-deploy@biahflow-hml`. Do output `wif_provider`, criar a variável de
   repositório `WIF_PROVIDER_HML`.
2. `envs/global/dns`, `envs/hml/servicos`, `envs/hml/eliseu-demo` — daí em
   diante o CI dá conta.
3. `envs/prd/wif` quando produção existir; o output vira `WIF_PROVIDER_PRD`.
   Enquanto essa variável não existir, os jobs de prd ficam desligados.

Também é preciso o secret `CLOUDFLARE_API_TOKEN` no repositório.

## Imports

Recurso que já existe é adotado por bloco `import {}` num `imports.tf` do
stack, nunca por `terraform import` na mão: o bloco fica no PR, aparece no plan
e é revisável. Depois do apply que o consome, o bloco vira ruído (o Terraform
reavalia todo import a cada plan) e sai em PR de limpeza.

Hoje só `envs/hml/wif` tem imports pendentes: o pool `github`, o provider OIDC,
a SA `hml-deploy` e o binding dela. O primeiro plan desse stack mostra uma única
mudança esperada — a `attributeCondition` do provider ganhando
`"biahflow/infra"`, para que este repositório possa autenticar.

## Convenções

- Um arquivo por papel: `versions.tf` (versões e backend), `variables.tf`,
  `main.tf`, `outputs.tf`, `imports.tf` quando houver adoção.
- Descrição em toda variável e todo output, em pt-BR. Comentário explica
  *por quê*; o *o quê* está no código.
- Valor do mundo real (projeto, região, bucket, lista de repositórios) entra
  como `default` de variável, não literal solto no meio do `main.tf`.
- `.terraform.lock.hcl` é versionado nos stacks — é o que garante que CI e
  máquina local usem o mesmo provider. Nos módulos, não.
- Nada de chave de service account: o CI entra por OIDC, a máquina local por
  ADC.

## Disciplina de PR

O plano Free não oferece branch protection em repositório privado, então a
regra é acordo, não trava:

- toda mudança vai por PR, mesmo trivial;
- ler o plan no resumo do job antes de aprovar — o plan É a revisão;
- `create`/`replace`/`destroy` inesperado no plan é motivo de parar, não de
  seguir com cuidado;
- merge na main aplica sozinho, em ordem fixa (`hml/wif` → `global/dns` →
  `hml/servicos` → `hml/eliseu-demo`; `prd/wif` em paralelo). Fazer merge
  quando houver alguém para acompanhar.
