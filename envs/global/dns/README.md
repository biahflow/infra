# `envs/global/dns`

Zona Cloudflare `biahflow.ai` como dado (`data cloudflare_zone`) e o `zone_id`
como output. A zona em si é gerenciada fora do Terraform.

Registros compartilhados — os que não pertencem a um ambiente nem a um serviço
(apex, MX, verificações de domínio) — entram aqui sob demanda. Registro de um
serviço fica no stack do serviço, junto do recurso que ele endereça: é lá que a
mudança de infraestrutura e a mudança de DNS precisam acontecer no mesmo plan.

Credencial: `CLOUDFLARE_API_TOKEN` (Zone Read + DNS Edit). O estado mora em
`gs://biahflow-hml-tfstate/envs/global/dns`, então o apply também exige a
credencial GCP de hml.
