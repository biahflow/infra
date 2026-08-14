# Adoção do que já existe em biahflow-hml. Estes blocos são TEMPORÁRIOS: depois
# que o apply que os consome estiver no estado, eles viram ruído (o Terraform
# reavalia todo import a cada plan). Removê-los em PR de limpeza pós-apply.
#
# Nenhum destes recursos é recriado — o único diff esperado no primeiro plan é a
# attributeCondition do provider ganhando "biahflow/infra".

import {
  to = module.wif.google_iam_workload_identity_pool.this
  id = "projects/biahflow-hml/locations/global/workloadIdentityPools/github"
}

import {
  to = module.wif.google_iam_workload_identity_pool_provider.this
  id = "projects/biahflow-hml/locations/global/workloadIdentityPools/github/providers/github"
}

import {
  to = module.wif.google_service_account.deploy
  id = "projects/biahflow-hml/serviceAccounts/hml-deploy@biahflow-hml.iam.gserviceaccount.com"
}

# Índice [0] porque o binding do módulo é condicional (`count`) — existe porque
# `deploy_sa_repos` não está vazia.
import {
  to = module.wif.google_service_account_iam_binding.deploy[0]
  id = "projects/biahflow-hml/serviceAccounts/hml-deploy@biahflow-hml.iam.gserviceaccount.com roles/iam.workloadIdentityUser"
}
