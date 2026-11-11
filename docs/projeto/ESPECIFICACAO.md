# FoodBridge Core — Auth, RLS, documentos e Edge Functions

**v2.1.0 proposta**, 11/11/2026 · snapshot histórico de código auditado `141f2c60b4d6f55768ca99c2d268f766165dc9c0`. Inspeção estática; não houve execução de integração nesta revisão.

## Evolução de autorização — proposta no PR #3 (sem deploy)

**Código de referência do PR:** [`c12899bc71222b6581fb77715b09c8b2b226a914`](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/commit/c12899bc71222b6581fb77715b09c8b2b226a914). O merge e a aplicação da migração SQL em Supabase remoto **não** foram realizados; o código SQL incremental foi preparado e aprovado em PostgreSQL efêmero. A descrição original a seguir ainda retrata o estado inicial da `main`.

| Superfície | Comportamento no código proposto | Invariante | Cobertura |
|---|---|---|---|
| `registrar-usuario` | Rejeita `ADMIN` e qualquer `tipo_usuario` fora de DONOR, PRODUCER, DISTRIBUTOR, NGO **antes** de chamar `auth.admin.createUser` | Nenhum cadastro público é autorizado a criar ADMIN | 1 teste unitário de política; HTTP pendente |
| `registrar-usuario` | Exige CNPJ textual de 14 dígitos após remover máscara; grava tipo legítimo em `app_metadata.tipo_usuario` e mantém cópia em `user_metadata` para compatibilidade temporária | `user_metadata` **não** é fonte de privilégios | Contratos de CNPJ e trigger pendentes |
| `aprovar-usuario` | Rejeita Bearer ausente (401), sessão sem usuário (401), falta de `app_metadata.tipo_usuario === ADMIN` (403) e perfil diferente de ADMIN/VERIFIED (403) | Autorização requer dado controlado pelo backend **e** estado atual do perfil | 2 unitários de função de decisão; integração HTTP pendente |
| `aprovar-usuario` | Verifica `usuario_id` como string e `aprovar` como boolean antes de atualizar perfil | Evita tipos inesperados na requisição | Teste HTTP pendente |

**Fronteira de confiança:** `raw_user_meta_data` é editável pelo titular e não pode estabelecer ADMIN. `app_metadata` só deve ser alterado por serviço privilegiado. O perfil `perfis.funcao/status` hoje pode estar sujeito à política de UPDATE do próprio usuário; **a migração RLS inicial continua vulnerável na main; há uma migração corretiva no PR #3, não aplicada**. O trigger `gerar_perfil_automatico` da migração inicial extrai `tipo_usuario` de `raw_user_meta_data`; a migração corretiva proposta passa a ler somente `raw_app_meta_data`. O bloqueio duplo da Edge Function mitiga a aprovação, mas **não bloqueia toda atribuição de papel ADMIN no banco**.

**Provisionamento:** não há endpoint público de promoção. Um operador autorizado deve escolher administradores legítimos e gravar explicitamente `app_metadata.tipo_usuario = ADMIN` via Admin API, preservando os demais metadados, somente após revisar sua identidade e status. Ausência dessa marca nega aprovação por padrão. Esse procedimento não foi executado.

**Evidência:** [GitHub Actions run 43082223462](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43082223462), job `role-policy` concluído **success**, com 3 testes unitários. Há também [CI #43085481171](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43085481171) com testes de política e SQL **aprovados** no PostgreSQL 17 efêmero. Não houve check Deno, testes E2E/HTTP, Supabase completo ou deploy verificado.

## Correção SQL incremental — esquema de perfis (2.1.0 proposta)

**Fonte:** migração [`supabase/migrations/20261111193000_secure_profile_roles.sql`](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/blob/fix/p0-trusted-admin-authorization-20261111/supabase/migrations/20261111193000_secure_profile_roles.sql) no PR #3. A migration original é preservada no histórico, para aplicar incrementalmente em bancos que já usaram a baseline.

| Camada | Antes (main) | Depois (na branch PR #3) | Verificação |
|---|---|---|---|
| `perfis` — UPDATE | Policy permissiva `USING(auth.uid()=id)`, com possibilidade de alterar funcao/status se grants autorizarem | REVOKE amplo seguido de UPDATE **apenas de nome, telefone** + SELECT self; policy `TO authenticated` com `USING` e `WITH CHECK` | Job PostgreSQL 17 sucesso; PostgREST real pendente |
| `gerar_perfil_automatico` | `raw_user_meta_data.tipo_usuario` | `raw_app_meta_data.tipo_usuario` validado + fallback DONOR | Teste SQL reproduz `user_metadata=ADMIN` e confirma DONOR |
| Função privilegiada | SECURITY DEFINER sem search_path restrito | `search_path=''`, referências qualificadas, EXECUTE revogado de usuários comuns | Revisão completa de funções e grants pendente |
| Administradores legados | Possível origem não confiável de ADMIN em cadastros antigos | Não há promoção nem demissão automática; precisa auditoria de identidades e `app_metadata` | Gate humano/operacional **pendente** |

**Evidência SQL:** [run 43085481171](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43085481171). Esses testes usam fixture reduzida de Auth/RLS, e não garantem comportamento do Supabase completo. A migração **não foi aplicada a nenhum banco conectado**. Ler [procedimento e riscos](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/blob/fix/p0-trusted-admin-authorization-20261111/docs/seguranca/PERFIS_AUTORIZACAO.md).

## Componentes, contratos e limites
Esta implementação utiliza Supabase Auth, Postgres/PostGIS, Storage e duas Edge Functions Deno/TypeScript. O SQL `supabase/migrations/20260313_init.sql` define enums `funcao_usuario` (DONOR, PRODUCER, DISTRIBUTOR, NGO, ADMIN), `status_usuario`, `status_organizacao`, `tipo_documento`, `status_documento`, `unidade_medida`, `tipo_doacao` e `status_doacao`. Cria `perfis` referenciando `auth.users`, `organizacoes`, `documentos`, `doacoes` com coordenada `geography(Point,4326)` e índice GIST, e `registros_auditoria`. Há políticas RLS, incluindo `perfis_select_self`, `organizacoes_read`, `organizacoes_owner`, `documentos_owner`, `doacoes_read` e `doacoes_owner`.

`registrar-usuario/index.ts` usa cliente service_role **somente em Edge Function**, recebe email, senha, role, CNPJ, PDF base64, nome de arquivo, nome completo e telefone; cria usuário confirmado no Auth, grava metadata e faz upload ao bucket `documentos-verificacao` em `{cnpj}/{nome_arquivo}` com `upsert:true`. **Risco real:** se o upload falhar depois de criar usuário, o código não reverte o Auth. O nome de arquivo também merece sanitização/validação; CORS está definido como `*`. Nunca expor SUPABASE_SERVICE_ROLE_KEY ao frontend.

`aprovar-usuario/index.ts` valida o JWT via supabaseClient.auth.getUser(), consulta função ADMIN na tabela `perfis` com cliente privilegiado, atualiza status para VERIFIED ou PENDING_VERIFICATION e tenta inserir `registros_auditoria`. O código não verifica a falha do insert da auditoria; uma autorização válida pode alterar status sem registro de auditoria. A política `perfis_update_self` deve ser auditada para impedir alteração do próprio papel/status por usuário comum. A migração possui trigger SECURITY DEFINER para criação automática de perfis, que exige revisão de privilégios e search_path.

As funções e migrações são distintas do backend Kotlin FoodBridge. Não aplicar migração Supabase ao PostgreSQL Oracle e não assumir que ambos compartilham estado canônico. O workflow `.github/workflows/deploy-functions.yml` administra funções com credenciais específicas: não modificar secrets em documentação.

## Execução em ambiente isolado
```bash
supabase functions serve --env-file .env.local
```

A referência real de funcionalidades é o código e os documentos originais do projeto. Mudanças no comportamento exigem revisão de [UML](../uml/README.md), [testes](../testes/PLANO_DE_TESTES.md) e controle documental.


## Próximos requisitos obrigatórios

- **SUP-RBAC-01:** funções de autorização não devem usar metadados editáveis por usuários nem perfis atualizáveis pelos próprios titulares como única prova de ADMIN.
- **SUP-RBAC-02:** bloquear `perfis.funcao`, `perfis.status` e `perfis.id` contra escritas não autorizadas no Data API; usar grants e RLS com `WITH CHECK` conforme modelo de privacidade definido.
- **SUP-RBAC-03:** refatorar `gerar_perfil_automatico` para nunca atribuir ADMIN com base em `raw_user_meta_data`; definir `search_path` e privilégios mínimos para o SECURITY DEFINER.
- **SUP-RBAC-04:** criação de usuário + upload documental deve ser atômica ou ter compensação/reconciliação e tratamento de falhas de auditoria.
- **SUP-RBAC-05:** habilitar apenas administradores designados, com evidência e revisão independente; nenhuma migração deve elevar automaticamente usuários existentes.

Consulte o [registro de riscos versionado](RISCOS.md), [plano de testes](../testes/PLANO_DE_TESTES.md) e [controle](../controle/VERSIONAMENTO.md).
