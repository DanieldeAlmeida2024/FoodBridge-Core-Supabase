# FoodBridge Core — Auth, RLS, documentos e Edge Functions

**v1.0.0**, 11/11/2026 · código auditado `141f2c60b4d6f55768ca99c2d268f766165dc9c0`. Inspeção estática; não houve execução de integração nesta revisão.

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
