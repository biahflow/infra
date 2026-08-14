# `envs/hml/eliseu-demo`

Hostname público do demo: `eliseu-demo.biahflow.ai` → registro CNAME na
Cloudflare + domain mapping do Cloud Run em `biahflow-hml`.

Cópia de `plataforma-oikos/ops/terraform` com os **endereços de recurso
preservados** (`data.cloudflare_zone.this`, `cloudflare_record.demo`,
`google_cloud_run_domain_mapping.demo`). Só isso permite migrar o estado local
antigo para `gs://biahflow-hml-tfstate/envs/hml/eliseu-demo` sem recriar o
registro DNS. Renomear qualquer um deles quebra a migração.

## Migração do estado (uma vez)

```bash
terraform -chdir=envs/hml/eliseu-demo init                 # backend novo, vazio
# a partir do diretório antigo, com o estado local em mãos:
#   terraform state push  ou  init -migrate-state
```

## Diferenças em relação ao original

1. `backend "gcs"` (o original usava estado local);
2. `var.servico` passou de `oikos-proto-web` para `eliseu-hml`;
3. comentários.

A mudança de `var.servico` **substitui** o domain mapping no apply
(`spec.route_name` não é atualizável no lugar): há uma janela curta sem o
hostname enquanto o Google reemite o certificado gerenciado. Fazer com
`envs/hml/servicos` já aplicado — daí a ordem fixa dos jobs em `apply.yml`.

Credenciais: GCP de hml + `CLOUDFLARE_API_TOKEN` (Zone Read + DNS Edit).
