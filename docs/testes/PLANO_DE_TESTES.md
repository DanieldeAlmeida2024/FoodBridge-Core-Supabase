# Plano de testes — FoodBridge Core — Auth, RLS, documentos e Edge Functions

**v2.1.0 proposta**, 11/11/2026 · snapshot histórico de código auditado `141f2c60b4d6f55768ca99c2d268f766165dc9c0`. Inspeção estática; não houve execução de integração nesta revisão.

| ID | Teste | Aceitação | Execução |
|---|---|---|---|
| SUP-01 | Criar usuário com documento PDF válido | Auth criado, perfil por trigger e upload no bucket | Pendente |
| SUP-02 | CNPJ com máscara | Prefixo de storage normalizado | Pendente |
| SUP-03 | Upload falha após Auth | Rollback/compensação e estado reconciliável | Pendente |
| SUP-04 | Usuário comum chama aprovar-usuario | 403 ou erro sem alteração | Pendente |
| SUP-05 | Admin aprova usuário | Status VERIFIED e auditoria criada | Pendente |
| SUP-06 | Inserção de auditoria falha | Não declarar aprovação auditada sem evidência | Pendente |
| SUP-07 | RLS perfis_update_self | Usuário não altera funcao/status arbitrariamente | Pendente |
| SUP-08 | RLS doacoes_read | Só status AVAILABLE visível a papéis permitidos | Pendente |
| SUP-09 | Documentos de outro usuário | Sem acesso horizontal por RLS/Storage | Pendente |
| SUP-10 | CORS e nome_arquivo malicioso | Rejeição/sanitização antes do upload | Pendente |
| SUP-11 | PostGIS para doações | Índice geography e consultas estáveis | Pendente |
| SUP-12 | Reaplicar migration em ambiente novo | Migrações determinísticas sem perda | Pendente |
| SUP-13 | Credencial service_role no client | Nenhuma ocorrência no bundle/frontend | Pendente |

## Estratégia e evidências
Separar testes unitários com dependências simuladas, integração em ambiente de desenvolvimento isolado e E2E com dados sintéticos. Para sistemas Supabase, validar RLS sob usuário comum versus administrador antes de ativar fluxos; para protótipo UX, não inferir backend pela UI. Registrar SHA do código, fixtures, versão de serviços, status e evidências, sem expor documentos, tokens ou dados reais.


## Testes incrementais de segurança — PR #3

Os **13 casos SUP-01 a SUP-13 acima continuam planejados e não executados** por esse PR; os cenários abaixo ampliam o catálogo para **21 casos de aceitação planejados**. Os três testes em `tests/role-policy.test.ts` são **unitários da política**, não validações E2E desses 21 cenários.

| ID | Cenário de aceitação | Resultado esperado | Evidência / situação |
|---|---|---|---|
| SUP-14 | POST de cadastro com `tipo_usuario = ADMIN` | 400 sem criar usuário | Política unitária aprovada no CI; HTTP pendente |
| SUP-15 | Cadastro com tipo estranho, numérico ou null | 400, nenhuma escrita privilegiada | Política unitária aprovada no CI; HTTP pendente |
| SUP-16 | Usuário modifica `user_metadata.tipo_usuario = ADMIN` e chama aprovação | 403, perfil-alvo inalterado | Política unitária aprovada no CI; Auth/HTTP pendente |
| SUP-17 | Admin validado somente por `app_metadata` confiável | 200 e evento de auditoria, quando `perfis` é ADMIN/VERIFIED | Unitário de política aprovado; integração pendente |
| SUP-18 | Mesmo usuário ADMIN com perfil `SUSPENDED` ou `PENDING_VERIFICATION` | 403 sem update | Integração pendente |
| SUP-19 | Usuário atualiza `perfis.funcao/status` pelo Data API | 403 ou alteração de 0 linhas; dado original preservado | SQL PostgreSQL 17 aprovado; API real pendente |
| SUP-20 | Trigger automático recebe metadata `ADMIN` editável | Novo perfil não pode receber ADMIN sem provisionamento confiável | SQL PostgreSQL 17 aprovado; Supabase Auth real pendente |
| SUP-21 | Edge Function sem Bearer ou com JWT expirado e dados inválidos | 401 e sem mutação | HTTP/Deno pendentes |

### Registro de execução (não equivale à aceitação de ponta a ponta)

| Teste em `tests/role-policy.test.ts` | Resultado | Evidência |
|---|---|---|
| Cadastro público aceita apenas DONOR/PRODUCER/DISTRIBUTOR/NGO | **Aprovado (unitário)** | CI 43082223462 |
| `user_metadata` não confere ADMIN | **Aprovado (unitário)** | CI 43082223462 |
| Somente `app_metadata` assinala ADMIN na função pura | **Aprovado (unitário)** | CI 43082223462 |

[CI da política](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43082223462): três testes unitários aprovados.

[CI de migração e política](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43085481171): `role-policy` **success** e `rls-security` **success** no PostgreSQL 17 efêmero. A fixture SQL cobre atribuição confiável de função, UPDATE de coluna, RLS próprio/cross-user e negação de mudanças de papel/status/email; **não** testa um deployment Supabase completo, migração em banco FoodBridge, Auth HTTP, Storage ou Deno. Os **21 cenários continuam sendo aceitação planejada**.


## Dependências de execução (v2.1.0)

- Teste SQL atual: `tests/sql/bootstrap_auth.sql` + `tests/sql/test_profile_security.sh` no PR #3, aplicado ao migration `supabase/migrations/20261111193000_secure_profile_roles.sql`, run #43085481171 **aprovado**.
- TESTE SUP-19/20 não se encerra somente pelo SQL na fixture: exige PostgREST com papel `authenticated`, trigger no Supabase Auth real e auditoria de concessões herdadas.
- Testes SUP-03/06/08/09/10/11/12/13/17/18/21 e cenários HTTP ainda pendentes.
