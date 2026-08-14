# Módulo `github-wif`

Federação OIDC do GitHub Actions com um projeto GCP, sem chave de service
account:

- `google_iam_workload_identity_pool` + `google_iam_workload_identity_pool_provider`
  (issuer do GitHub, `google.subject = assertion.sub`,
  `attribute.repository = assertion.repository`);
- `attribute_condition` derivada de `repos_allowlist` — quem pode entrar;
- `google_service_account` de deploy + binding autoritativo de
  `roles/iam.workloadIdentityUser` derivado de `deploy_sa_repos` — quem pode
  usar essa SA.

`repos_allowlist` e `deploy_sa_repos` são listas diferentes de propósito: entrar
no pool não dá direito a impersonar a SA de deploy. Um stack que só precisa de
credencial própria (como o `infra-deploy`) entra na allowlist e declara o
próprio binding fora do módulo.

O binding de `deploy_sa_repos` é autoritativo: remover um repositório da lista
remove o acesso dele no próximo apply. Com a lista vazia o binding não é criado
(a API do IAM rejeita binding sem members).

Campos cosméticos (`display_name`, `description`) não são declarados de
propósito — o módulo cuida de identidade e autorização; nomes de exibição
divergentes no mundo vivo aparecem como diff no primeiro plan pós-import.
