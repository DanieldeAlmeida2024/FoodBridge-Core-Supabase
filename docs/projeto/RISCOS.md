# FB-SUP-RSK — Riscos rastreáveis

**Revisão:** 14/11/2026 · **código:** main `f6cbd343` · **implantações remotas:** não realizadas.

| Risco | Gravidade | Correção em código | Bloqueador de produção |
| --- | --- | --- | --- |
| SUP-R01 papel ADMIN em cadastro | Crítica | Cadastro rejeita ADMIN; app_metadata confiável | Teste HTTP real e revisão de contas |
| SUP-R02 trigger com user_metadata editável | Crítica | Migration lê raw_app_meta_data | Aplicar em staging e auditar admins legados |
| SUP-R03 autoedição de função/status | Crítica | Grants de coluna e RLS em perfis | Testar no PostgREST real |
| SUP-R04 autoaprovação de organização/documento | Crítica | SELECT/INSERT/UPDATE separados, status protegido | Homologar múltiplos papéis e storage |
| SUP-R05 doações auto-publicadas | Alta | DRAFT default, sem grants de estado | Endpoints transacionais autorizados |
| SUP-R06 falha após criação Auth | Alta | Compensação tenta excluir usuário | Falha de compensação, reconciliação |
| SUP-R07 upload malicioso | Alta | Limite PDF 2 MiB, assinatura, path por UUID | Varredura e política de retenção |
| SUP-R08 confirmação de e-mail insegura | Alta | **Não resolvido** (`email_confirm:true`) | Onboarding com verificação antes do acesso |
| SUP-R09 abuso de cadastro | Alta | Limite de JSON; **não há CAPTCHA/rate limit** | Proteção persistente upstream |
| SUP-R10 auditoria não transacional | Alta | **Não resolvido** | RPC/transaction de aprovação + log |
| SUP-R11 busca geográfica definer | Alta | Migração converte a invoker e revoga anon | Validar PostGIS e grants reais |
| SUP-R12 deploy para projeto errado | Crítica | Workflow manual com ref/ambiente explícitos | Configurar/proteger ambiente FoodBridge correto |

**Evidência parcial:** [CI da main #43648545626](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43648545626) passou em Node, PostgreSQL descartável e Deno. Isso demonstra contratos isolados, não implantação segura.

Nenhum dos itens abertos deve ser marcado como entregue sem teste reproduzível e histórico de alteração.
