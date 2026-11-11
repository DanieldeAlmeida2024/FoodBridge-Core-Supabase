# Supabase FoodBridge — plano de testes SQL, RLS e funções

> **FBS-DOC v1.0.0** | 11/11/2026 | commit `141f2c60b4d6f55768ca99c2d268f766165dc9c0` | inspeção estática, sem acesso ao ambiente hospedado.


## Situação
O repositório possui `tests/test_documentacao.py`, mas não foi encontrada suíte pgTAP/integração de RLS na árvore auditada. Os cenários são **critérios propostos** que devem ser executados em stack Supabase local descartável antes de uso hospedado.

| ID | Prioridade | Cenário | Critério |
|---|---|---|---|
| FBS-01 | P0 | Usuário novo escolhe `tipo_usuario=ADMIN` no cadastro | Escalada proibida; nunca conceder privilégio por user_metadata |
| FBS-02 | P0 | Seleção de perfil de outra pessoa | RLS impede leitura não autorizada |
| FBS-03 | P0 | UPDATE perfis de outro usuário | RLS `USING`/`WITH CHECK` impede mutação |
| FBS-04 | P0 | Ler organização como anon | Política explícita por campo/finalidade |
| FBS-05 | P0 | RPC `get_nearby_donations` sem token | Sem fuga de dados protegidos |
| FBS-06 | P0 | `SECURITY DEFINER` com `search_path` manipulado | Não executar SQL privilegiado inesperado |
| FBS-07 | P0 | Inscrição em Storage por usuário diferente | Documentos privados inacessíveis |
| FBS-08 | P0 | Aprovar usuário sem role ADMIN | Negado, nenhuma alteração nem auditoria falsa |
| FBS-09 | P0 | Falhar upload depois de criar Auth user | Compensação ou limpeza sem conta órfã |
| FBS-10 | P1 | Busca geo lat/lng/raio em limites | Só AVAILABLE, distância correta |
| FBS-11 | P1 | Migration em banco vazio | Idempotência limitada explicitada |
| FBS-12 | P1 | Trigger `updated_at` | Atualiza timestamp em perfis/doações |
| FBS-13 | P1 | RLS para múltiplos papéis | SELECT/INSERT/UPDATE/DELETE conforme matriz |

## Execução segura
Preparar stack local, fixtures sintéticas e roles `anon`, `authenticated` e `service_role` sem credenciais reais. Preferir pgTAP para teste de RLS e Deno testes mockados para Edge Functions. Não executar migrações ou testes destrutivos no projeto remoto. O P0 de atribuição ADMIN e o P0 de SECURITY DEFINER são **bloqueantes**, independentemente do CI documental.
