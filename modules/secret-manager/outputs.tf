output "ids" {
  description = "ID completo de cada secret, por nome — o que um serviço monta."
  value       = { for nome, s in google_secret_manager_secret.este : nome => s.id }
}

output "nomes" {
  description = "Nome (secret_id) de cada secret, por nome."
  value       = { for nome, s in google_secret_manager_secret.este : nome => s.secret_id }
}

output "versoes_correntes" {
  description = <<-EOT
    Nome da versão corrente de cada secret cujo valor este módulo governa
    (`projects/…/secrets/…/versions/N`). É identificador, não valor: serve para
    ver na saída do apply que uma rotação de fato gravou versão nova.
  EOT
  value       = { for nome, v in google_secret_manager_secret_version.corrente : nome => v.name }
}
