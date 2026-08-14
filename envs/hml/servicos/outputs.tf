output "eliseu_url" {
  description = "URL `run.app` do serviço eliseu-hml (o hostname público sai de envs/hml/eliseu-demo)."
  value       = module.eliseu.url
}

output "eliseu_nome" {
  description = "Nome do serviço, usado pelo domain mapping e pelo deploy do CI."
  value       = module.eliseu.nome
}
