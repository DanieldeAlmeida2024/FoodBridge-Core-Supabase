# UML — FoodBridge Core — Auth, RLS, documentos e Edge Functions

**v2.0.0 proposta**, 11/11/2026 · snapshot histórico de código auditado `141f2c60b4d6f55768ca99c2d268f766165dc9c0`. Inspeção estática; não houve execução de integração nesta revisão.

- [Arquitetura e fronteiras](01_componentes.puml)
- [Fluxo de cadastro e documentos (snapshot inicial)](02_sequencia.puml)
- [Fronteira de confiança e aprovação ADMIN proposta no PR #3](03_sequencia_autorizacao_admin.puml)

Diagramas representam módulos observados e critérios de aceitação, não são prova de integração concluída.

O terceiro diagrama representa **código proposto em PR #3**, não banco já migrado. Atribuição inicial de ADMIN via `raw_user_meta_data` e UPDATE de `perfis` continuam riscos na migração SQL original; ver [registro de riscos](../projeto/RISCOS.md).
