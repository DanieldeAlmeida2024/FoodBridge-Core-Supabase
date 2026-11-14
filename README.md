# FoodBridge Core — backend experimental Supabase

Implementação alternativa e **independente** de backend para redistribuição de alimentos, estudando **Supabase Auth, PostgreSQL/PostGIS, Row Level Security (RLS), Storage e Edge Functions Deno**. Este repositório não representa a API Kotlin nem sua infraestrutura Oracle.

## Estado verificável

- **Código disponível:** migrações de perfis, organizações, documentos, doações e consultas geográficas; Edge Functions `registrar-usuario` e `aprovar-usuario`.
- **Segurança versionada:** uma migração incremental de autorização, `20261111193000_secure_profile_roles.sql`, substitui confiança em `user_metadata` por `app_metadata` e aplica grants de coluna + RLS a perfis, organizações, documentos e doações.
- **CI:** [validação Node, PostgreSQL 17 descartável e Deno 2](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43648235836). Os testes verificam negação de elevação de papel, permissões de atualização, isolamento por proprietário, validação de entrada e compilação das funções. **Não são testes E2E de Auth/PostgREST/Storage real.**
- **Publicação:** o deploy automático está desativado por segurança. O workflow requer execução manual, variáveis do projeto FoodBridge, ref exata e ambiente de aprovação. Nenhuma migração deste trabalho foi aplicada em banco remoto.

## Limites e invariantes de autorização

| Recurso | Usuário autenticado | Operação privilegiada |
| --- | --- | --- |
| Perfis | Ler o próprio perfil; editar nome e telefone | Papel, e-mail, status e identidade |
| Organizações | Criar registro pendente, consultar próprio ou verificado, editar dados permitidos | Verificação e troca de responsável |
| Documentos | Consultar apenas documentos próprios | Upload por Edge Function, verificação e auditoria |
| Doações | Criar/editar apenas rascunhos, consultar próprias ou disponíveis | Publicação, reivindicação e mudança de status |
| Busca geográfica | Consultar registros autorizados pela RLS | Rotas administrativas e mudanças de estado |

A Edge Function de cadastro rejeita `ADMIN`, valida CNPJ (dígitos verificadores), e-mail, senha de pelo menos 12 caracteres e PDF de até 2 MiB; limita JSON a 3 MiB, não usa nomes de arquivo do cliente, não sobrescreve documentos e tenta compensar falha de upload desfazendo a conta.

## Bloqueadores antes de disponibilizar a usuários reais

1. **Verificação de e-mail:** o fluxo ainda usa `email_confirm: true` em criação administrativa; isso não comprova posse do endereço. Substituir por onboarding com confirmação verificada.
2. **Antiautomação:** registrar rate limiting persistente e CAPTCHA/antiabuso conforme os limites do produto. O cadastro público que executa ações com service role não deve ser exposto antes disso.
3. **Transações:** aprovação e trilha de auditoria ainda precisam de operação atômica; falha parcial não pode produzir status sem recibo.
4. **Documentos:** validar conteúdo completo/antimalware, política de retenção e permissões reais do Storage; o cabeçalho `%PDF-` não comprova segurança do documento.
5. **Dados:** executar a migração em um projeto de staging FoodBridge identificado e autorizado, após backup, auditoria de perfis ADMIN legados e testes completos Auth, PostgREST, Storage e PostGIS.
6. **Política operacional:** provisionamento administrativo auditável, recuperação, revogação, controles de acesso e análise LGPD.

Nenhum desses requisitos pode ser considerado concluído apenas porque o CI está verde.

## Reprodução local e testes

Instale a CLI Supabase, Docker e, para a suíte de controle de acesso, Node 22, Deno 2 e PostgreSQL de testes. Nunca aponte testes SQL para produção.

```bash
supabase start
supabase migration list --local
supabase functions serve registrar-usuario
```

A suíte do GitHub Actions cria PostgreSQL 17 descartável com `tests/sql/bootstrap_auth.sql`, aplica a migração pendente e executa:
```bash
node --experimental-strip-types --test tests/role-policy.test.ts
bash tests/sql/test_profile_security.sh
bash tests/sql/test_resource_security.sh
deno check supabase/functions/registrar-usuario/index.ts supabase/functions/aprovar-usuario/index.ts
```

Os comandos SQL pressupõem a fixture de CI inicializada e acesso administrativo **somente a um banco descartável**. Não devem ser executados cegamente contra um projeto hospedado.

## Documentação específica

- [Política de autorização, riscos e procedimento de implantação](docs/seguranca/PERFIS_AUTORIZACAO.md)
- [Plano de testes](docs/PLANO_TESTES.md)
- [Arquitetura](docs/ARQUITETURA.md)
- [Requisitos](docs/REQUISITOS.md)
- [UML](docs/UML.puml)
- [Workflow de controle de deploy](.github/workflows/deploy-functions.yml)

**Status:** implementação experimental versionada; proteção de código revisada, produção não homologada e nenhum projeto Supabase FoodBridge remoto confirmado para implantação.
