# Serviços Cloud Run de produção — ainda não existe nenhum.
#
# Quando o eliseu for para produção, este stack recebe:
#
#   module "eliseu" {
#     source        = "../../../modules/cloud-run-service"
#     nome          = "eliseu-prd"
#     project       = "biahflow-prd"
#     region        = "us-east1"
#     image_inicial = "<imagem promovida de hml>"
#     min_instances = 1   # produção não escala a zero: cold start é sintoma
#     max_instances = 10
#   }
#
# Junto disso é preciso: `versions.tf` com o backend
# `gcs { bucket = "biahflow-prd-tfstate", prefix = "envs/prd/servicos" }`,
# `provider "google"`, e a entrada deste stack na detecção de mudanças de
# `.github/workflows/plan.yml` e `apply.yml` (hoje fora da matriz porque não há
# o que planejar).
