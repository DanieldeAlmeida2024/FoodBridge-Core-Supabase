# FoodBridge Core Supabase — riscos de segurança e pendências

**Documento:** FB-SUP-RSK · **Versão:** 2.1.0 proposta · **Data:** 11/11/2026.
Baseline SQL atual: `141f2c60b4d6f55768ca99c2d268f766165dc9c0`. Código de mitigação da função: `c12899bc71222b6581fb77715b09c8b2b226a914` ([PR #3](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/3)).

| ID | Gravidade | Superfície / evidência | Situação | Tratamento para encerramento |
|---|---|---|---|---|
| SUP-R01 | Crítica | `registrar-usuario` aceitava `tipo_usuario=ADMIN` fornecido pelo cliente | **Mitigado na branch PR #3**, sem merge | HTTP test 400, revisão e deploy controlado |
| SUP-R02 | Crítica | Trigger `gerar_perfil_automatico` atribui `perfis.funcao` a partir de `raw_user_meta_data` editável | **Mitigação SQL implementada no PR #3; ainda não aplicada** | Verificar trigger no Supabase FoodBridge, revisar admins legados; SUP-20 |
| SUP-R03 | Crítica | Política `perfis_update_self` permite UPDATE do perfil próprio, sem proteção de colunas de função/status | **Mitigação SQL implementada no PR #3; ainda não aplicada** | Validar grants herdados, PostgREST e Supabase real; SUP-19 |
| SUP-R04 | Crítica | `aprovar-usuario` confiava apenas em `perfis.funcao=ADMIN`, potencialmente alterável pelo usuário | **Mitigado na branch PR #3**, sem merge | Requer `app_metadata` ADMIN mais perfil ADMIN/VERIFIED; teste HTTP SUP-16/17/18 |
| SUP-R05 | Alta | `registrar-usuario`: usuário Auth criado antes do upload do PDF; falha no Storage deixa conta parcial | **Aberto** | Compensação/fluxo transacional, tests SUP-03 |
| SUP-R06 | Alta | `aprovar-usuario`: INSERT em `registros_auditoria` não é checado | **Aberto** | Falha auditável bloqueia operação ou mecanismo outbox, test SUP-06 |
| SUP-R07 | Alta | `registrar-usuario`: `nome_arquivo` não sanitizado, `upsert: true`, CORS `*` | **Aberto** | Validar tipo/tamanho/nome de arquivo, anti-overwrite, política CORS, SUP-10 |
| SUP-R08 | Alta | RLS `organizacoes_owner`, `documentos_owner`, `doacoes_owner` são `FOR ALL` sem `WITH CHECK` explícito e fluxos de autorização insuficientemente testados | **Aberto para auditoria** | Separar políticas por operação e validar ownership/status em ambiente isolado |
| SUP-R09 | Alta | `SECURITY DEFINER` no schema exposto sem `search_path` estrito | **Parcialmente mitigado na migração PR #3** | search_path fixo/EXECUTE revogado; revisar outras funções SECURITY DEFINER |
| SUP-R10 | Alta | Nenhuma comprovação de Deno check, RLS em instância isolada, E2E nem publicação do PR #3 | **Parcialmente mitigado: SQL CI aprovado** | Ainda faltam Deno, Auth/HTTP completo e deploy |

Os testes **unitários** do CI #43082223462 e o [CI SQL #43085481171](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43085481171) aprovaram `role-policy` e `rls-security` (PostgreSQL 17 efêmero). **Não encerram SUP-R02/R03 em produção**: a migração ainda não foi aplicada ao Supabase FoodBridge e o cenário de admins legados não foi auditado. Ver [guia de migração no PR #3](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/blob/fix/p0-trusted-admin-authorization-20261111/docs/seguranca/PERFIS_AUTORIZACAO.md).

## Critério de liberação

- Negar promoção por metadata de usuário ou UPDATE de perfil por conta não privilegiada.
- Exigir testes da função administrativa com identidades e status distintos.
- Auditar Storage e compensação de registros.
- Validar a migração em ambiente FoodBridge isolado e registrar SHA, checks e responsáveis.
- Somente após revisão e testes, discutir merge e publicação.
