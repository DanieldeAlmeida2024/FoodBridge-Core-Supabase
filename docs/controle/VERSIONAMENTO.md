# FoodBridge Core Supabase — controle de versões documentais

**Documento:** FB-SUP-CTRL · **Versão documental proposta:** 2.0.0 · **Atualizado:** 11/11/2026.
A versão **2.0.0 é proposta de contrato de autorização**: o código correspondente existe no [PR de segurança #3](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/3), mas **não está integrado à `main` nem publicado**. A documentação está no [PR #2](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/pull/2), independente.

| ID | Documento | Versão | Estado |
|---|---|---|---|
| FB-SUP-PROJ | [Especificação de Auth/RLS/Edge Functions](../projeto/ESPECIFICACAO.md) | 2.0.0 proposta | Reflete PR #3 e explicita riscos existentes |
| FB-SUP-RSK | [Riscos e pendências](../projeto/RISCOS.md) | 2.0.0 proposta | Sem encerramento dos riscos SQL |
| FB-SUP-TST | [Plano de testes](../testes/PLANO_DE_TESTES.md) | 2.0.0 proposta | 13 cenários originais + 8 novos; 3 testes unitários CI aprovados |
| FB-SUP-UML | [Diagramas](../uml/README.md) | 2.0.0 proposta | Componentes e sequência de confiança administrativa |

## Histórico de versões

| Versão | Data | Código de referência | Escopo e evidências |
|---|---|---|---|
| 1.0.0 | 11/11/2026 | `141f2c60b4d6f55768ca99c2d268f766165dc9c0` | Snapshot da implementação inicial; 13 testes planejados e 2 UML, sem execução de integração |
| 2.0.0 (proposta) | 11/11/2026 | `c12899bc71222b6581fb77715b09c8b2b226a914` em PR #3 | Mudança de contrato: ADMIN proibido no cadastro público; aprovação exige `app_metadata` confiável + perfil ADMIN/VERIFIED. 3 unitários passaram no [CI 43082223462](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43082223462). Migração e integração pendentes |

**SemVer documental:** MAJOR = alteração de contrato/regra de autorização; MINOR = adição de funcionalidade compatível; PATCH = precisão editorial/evidência. Esta numeração **não** é release de software nem confirma implantação.

## Bloqueadores para considerar 2.0.0 integrado

- [ ] Merge revisado dos PRs #2 (documentação) e #3 (código), com prevenção de conflitos.
- [x] Job unitário `role-policy` verde no CI; **não implica** deploy da Edge Function.
- [ ] Migração adicional para remover UPDATE de `perfis.funcao/status` por usuário comum e corrigir trigger baseado em `raw_user_meta_data`.
- [ ] Execução do SQL em **ambiente Supabase FoodBridge descartável**, com testes RLS e grants; não aplicar em ArenaSoft ou AnimeDex.
- [ ] Deno check / testes HTTP de cada função; testar registro, auth e erro de upload.
- [ ] Provisionar administradores legítimos de forma controlada via `app_metadata`, sem promoção automática de usuários.
- [ ] Validação de deploy com URLs, projeto-alvo e evidências seguras.

## Política de atualização

Mudança em `supabase/functions`, `supabase/migrations` ou regras RLS requer atualização conjunta de especificação, riscos, testes e diagramas, referenciando SHA e testes reais. Nunca reescrever a baseline histórica como se a implantação já tivesse ocorrido.
