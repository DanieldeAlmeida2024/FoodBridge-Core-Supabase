# FoodBridge Core — hardening de autorização de perfis

> **Documento:** FB-SUP-SEC-001 · **Versão documental:** 2.1.0 proposta · **Data:** 2026-11-11
> **Branch de código:** `fix/p0-trusted-admin-authorization-20261111` · [PR de segurança #3](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/3)
> **Documentação de arquitetura e testes:** [PR #2](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/2)

## Mudança incremental

A migração [`supabase/migrations/20261111193000_secure_profile_roles.sql`](../../supabase/migrations/20261111193000_secure_profile_roles.sql) corrige duas rotas de elevação de privilégio detectadas na migração inicial `20260313_init.sql`:

1. **RLS + permissões por coluna:** a policy de UPDATE passa a restringir a linha pelo `auth.uid()` com `USING` e `WITH CHECK`. O papel `authenticated` recebe UPDATE **somente de `nome` e `telefone`**. Não consegue gravar `id`, `email`, `funcao` nem `status` via Data API.
2. **Trigger de criação:** `gerar_perfil_automatico()` deixa de ler papel de `raw_user_meta_data`; considera somente `raw_app_meta_data.tipo_usuario` e aplica `DONOR` como fallback seguro. A função tem `SET search_path = ''` e `EXECUTE` revogado de funções RPC públicas.

A Edge Function do PR #3 rejeita `ADMIN` no registro público, grava papéis de cadastro legítimos em `app_metadata` e exige ADMIN tanto no perfil verificado quanto nos metadados confiáveis para aprovação.

## Riscos e compatibilidade

| ID | Risco anterior | Tratamento | Estado |
|---|---|---|---|
| SUP-R02 | Trigger confia em user_metadata editável | Nova migração usa app_metadata | Código preparado; banco não migrado |
| SUP-R03 | Usuário pode autoatribuir funcao/status | REVOKE + GRANT UPDATE(nome,telefone), RLS restritiva | Código preparado; banco não migrado |
| SUP-R04 | Aprovação privilegia perfil editável | Edge Function requer app_metadata confiável + perfil ADMIN/VERIFIED | Unitários CI aprovados, HTTP pendente |
| SUP-R09 | Definer exposto via public | search_path restrito e REVOKE EXECUTE | Implantação pendente |
| SUP-LEGACY-ADMIN | Admins legados podem ter sido promovidos via metadata antiga | Auditoria humana pré-deploy, nunca promover ou rebaixar automaticamente | **ABERTO** |

**Atenção:** não há projeto Supabase FoodBridge disponível nos conectores atuais. A migração não foi aplicada em Supabase remoto nem na VM Oracle. A versão documental não é release.

## Teste SQL automatizado

O workflow `.github/workflows/security-tests.yml` executa PostgreSQL 17 descartável com fixture reduzida:

- `tests/sql/bootstrap_auth.sql`: prepara Auth, perfil e política antiga **somente para teste**;
- `tests/sql/test_profile_security.sh`: comprova que `user_metadata=ADMIN` gera DONOR, que `app_metadata=ADMIN` gera ADMIN em contexto privilegiado, que RLS filtra os perfis e que UPDATE de papel/status/e-mail não é permitido;
- Esses testes **não** substituem a validação de uma instância Supabase completa com PostgREST, Auth, Edge Functions e Storage.

## Pré-requisitos antes da aplicação real

1. Identificar **projeto Supabase FoodBridge** correto; confirmar proprietário, ambiente e backups.
2. Fazer inventário somente leitura de grants/policies atuais e de todos os perfis ADMIN existentes. Revisar administradores humanos e app_metadata, sem confiar em valores de user_metadata antigos.
3. Validar `supabase migration list` e política de aplicação compatível com a versão da CLI usada; mudanças recentes da CLI v3 tornam o **alvo local padrão**. Não disparar migrations via secrets de deploy de funções sem conferência.
4. Aplicar migração em **staging FoodBridge autorizado**, com testes SQL, Auth, PostgREST, Edge Functions e auditoria. Corrigir diffs de grants existentes.
5. Somente após revisão e aceite do proprietário, planejar deploy produtivo com backup/rollback. Para regressão, restaurar de snapshot do banco ou migração compensatória revisada; **não conceder UPDATE em `funcao`/`status` para contornar falhas**.
6. Inspecionar permissões herdadas, policies adicionais e toda função SECURITY DEFINER exposta. Esta migração limita `public.perfis`, não substitui auditoria dos outros recursos.

## Registro de versão

| Versão | Escopo | Evidência |
|---|---|---|
| 2.0.0 proposta | Edge Functions com ADMIN confiável | Testes unitários `role-policy` aprovados em CI #43082223462 |
| 2.1.0 proposta | Migração incremental de RLS, grants e trigger, com testes SQL | CI #43085481171: role-policy e PostgreSQL 17 aprovados |

Relacionar esta alteração ao catálogo [testes de Supabase](../PLANO_TESTES.md) e ao [PR documental #2](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/2). A documentação especializada deve permanecer sincronizada na integração.

## Evidência de CI da migração

- **Execução:** [GitHub Actions 43085481171](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43085481171).
- **`role-policy`: success** (3 testes unitários Node, decisões administrativas de cadastro/aprovação).
- **`rls-security`: success** (PostgreSQL 17 efêmero; simulação do trigger legado, aplicação da migração, validação de RLS, grants e negativa de alteração de role/status/email).
- **Ainda não comprovado:** schema completo e todas as policies Supabase, migração aplicada em ambiente FoodBridge, testes HTTP/Edge/Auth/Storage, inspeção de admins legados e deploy.

O run validou o commit de código/migração `411362f678d1acd5b428e6c50a3ff2e05030a601`. Alterações documentais posteriores exigem confirmação de CI do novo HEAD.
