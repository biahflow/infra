# Secret Manager: casca, quem lê e o valor corrente de um conjunto de secrets.
#
# O módulo trata segredo como três coisas separadas, porque elas têm ciclos de
# vida diferentes: o secret existe (casca), alguém pode lê-lo (IAM) e ele tem um
# valor corrente (versão). Secret sem entrada em `var.valores` nasce e fica como
# casca — é o caso de valor que o Terraform não produz e não deve inventar.
#
# O valor, quando este módulo o governa, **fica no state**: `secret_data` é um
# argumento comum, e o provider precisa dele para detectar mudança. Isso é
# aceitável aqui porque os valores que este repositório gerencia nascem de outros
# recursos do próprio Terraform (chave HMAC, senha de role), e portanto já vivem
# no state pela origem — o secret version não piora o que já é verdade. Valor que
# venha de fora do Terraform tem caminho melhor (`secret_data_wo`, write-only,
# disponível no provider 6.x): ver README.

locals {
  # for_each precisa de um id estável por par secret×leitor.
  acessos = merge([
    for nome, s in var.secrets : {
      for email in s.acessores : "${nome}|${email}" => { secret = nome, email = email }
    }
  ]...)

  # `keys()` de um map sensível é sensível, e `for_each` recusa valor sensível.
  # O NOME do secret não é segredo — o valor é, e ele não passa por aqui.
  com_valor = toset(nonsensitive(keys(var.valores)))
}

resource "google_secret_manager_secret" "este" {
  for_each = var.secrets

  project   = var.project
  secret_id = each.key

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "acesso" {
  for_each = local.acessos

  project   = var.project
  secret_id = google_secret_manager_secret.este[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.email}"
}

# Trocar o valor substitui o recurso (a versão é imutável na API). Duas escolhas
# tornam a troca segura: a versão nova nasce antes de a antiga sair, para não
# existir instante sem `latest`; e a antiga é **desabilitada**, não destruída, de
# modo que voltar atrás seja reabilitar uma versão que ainda existe.
resource "google_secret_manager_secret_version" "corrente" {
  for_each = local.com_valor

  secret      = google_secret_manager_secret.este[each.key].id
  secret_data = var.valores[each.key]

  deletion_policy = "DISABLE"

  lifecycle {
    create_before_destroy = true
  }
}
