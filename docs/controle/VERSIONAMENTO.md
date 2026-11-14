# FB-SUP-CTRL — Versionamento técnico e documental

| Versão | Estado | Escopo | Evidência |
| --- | --- | --- | --- |
| 1.0.0 | Histórico | Esquema original e funções iniciais | Commit `141f2c60` |
| 2.1.0 | Integrado no código; não implantado | Política ADMIN, RLS de perfis e triggers | PR #3, testes Node/PG |
| 2.2.0 | Integrado no código; não implantado | Grants de organizações/documentos/doações, entrada segura, typecheck Deno, deploy manual | [main `f6cbd343`](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/commit/f6cbd34389ef421634f110d06e6a26510616c6dd) e [CI](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43648545626) |

**Regra:** qualquer nova migration/Edge Function atualiza a especificação, matriz de testes, riscos, UML e histórico no mesmo PR. Versão documental não é release de produto; status de produção depende de homologação remota, segurança e publicação.
