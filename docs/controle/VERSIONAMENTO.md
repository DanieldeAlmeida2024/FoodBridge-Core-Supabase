# FoodBridge Core Supabase — controle de versões documentais

**Documento:** FB-SUP-CTRL · **Versão documental proposta:** 2.1.0 · **Atualizado:** 11/11/2026.
A versão **2.1.0 é proposta de contrato de autorização e de esquema seguro**: o código correspondente existe no [PR de segurança #3](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/3), mas **não está integrado à `main` nem publicado**. A documentação está no [PR #2](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/2), independente.

| ID | Documento | Versão | Estado |
|---|---|---|---|
| FB-SUP-PROJ | [Especificação de Auth/RLS/Edge Functions](../projeto/ESPECIFICACAO.md) | 2.1.0 proposta | Reflete PR #3 e explicita riscos existentes |
| FB-SUP-RSK | [Riscos e pendências](../projeto/RISCOS.md) | 2.1.0 proposta | Mitigação SQL codificada/testada; risco operacional aberto até aplicar |
| FB-SUP-TST | [Plano de testes](../testes/PLANO_DE_TESTES.md) | 2.1.0 proposta | 21 cenários planejados; Node e PostgreSQL 17 CI aprovados parcialmente |
| FB-SUP-UML | [Diagramas](../uml/README.md) | 2.1.0 proposta | Quatro fontes UML, incluindo RLS e trigger |

## Histórico de versões

| Versão | Data | Código de referência | Escopo e evidências |
|---|---|---|---|
| 1.0.0 | 11/11/2026 | `141f2c60b4d6f55768ca99c2d268f766165dc9c0` | Snapshot da implementação inicial; 13 testes planejados e 2 UML, sem execução de integração |
| 2.0.0 (proposta) | 11/11/2026 | `c12899bc71222b6581fb77715b09c8b2b226a914` em PR #3 | Mudança de contrato: ADMIN proibido no cadastro público; aprovação exige `app_metadata` confiável + perfil ADMIN/VERIFIED. 3 unitários passaram no [CI 43082223462](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43082223462). Migração e integração pendentes |

| 2.1.0 (proposta) | 11/11/2026 | `411362f678d1acd5b428e6c50a3ff2e05030a601` em PR #3 | Migração incremental `supabase/migrations/20261111193000_secure_profile_roles.sql` com REVOKE/GRANT por coluna, RLS restrita e trigger de `raw_app_meta_data`; jobs `role-policy` + `rls-security` aprovados no [CI #43085481171](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43085481171). **SQL não aplicado a Supabase remoto** |

**SemVer documental:** MAJOR = alteração de contrato/regra de autorização; MINOR = adição de funcionalidade compatível; PATCH = precisão editorial/evidência. Esta numeração **não** é release de software nem confirma implantação.

## Bloqueadores para considerar 2.1.0 integrado

- [ ] Merge revisado dos PRs #2 (documentação) e #3 (código), com prevenção de conflitos.
- [x] Job unitário `role-policy` verde no CI; **não implica** deploy da Edge Function.
- [x] Código da migração incremental para bloquear UPDATE de `perfis.funcao/status` e corrigir o trigger **publicado no PR #3**, não aplicado remotamente.
- [x] SQL testado em **PostgreSQL 17 descartável com fixture Auth/RLS reduzida** no CI #43085481171.
- [ ] Migrar/testar em **ambiente Supabase FoodBridge completo e autorizado**, com PostgREST e funções; não aplicar em ArenaSoft ou AnimeDex.
- [ ] Deno check / testes HTTP de cada função; testar registro, auth e erro de upload.
- [ ] Provisionar administradores legítimos de forma controlada via `app_metadata`, sem promoção automática de usuários.
- [ ] Validação de deploy com URLs, projeto-alvo e evidências seguras.

## Política de atualização

Mudança em `supabase/functions`, `supabase/migrations` ou regras RLS requer atualização conjunta de especificação, riscos, testes e diagramas, referenciando SHA e testes reais. Nunca reescrever a baseline histórica como se a implantação já tivesse ocorrido.
