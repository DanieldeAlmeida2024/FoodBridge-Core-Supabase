# Plano de testes — FoodBridge Core — Auth, RLS, documentos e Edge Functions

**v1.0.0**, 11/11/2026 · código auditado `141f2c60b4d6f55768ca99c2d268f766165dc9c0`. Inspeção estática; não houve execução de integração nesta revisão.

| ID | Teste | Aceitação | Execução |
|---|---|---|---|
| SUP-01 | Criar usuário com documento PDF válido | Auth criado, perfil por trigger e upload no bucket | Pendente |
| SUP-02 | CNPJ com máscara | Prefixo de storage normalizado | Pendente |
| SUP-03 | Upload falha após Auth | Rollback/compensação e estado reconciliável | Pendente |
| SUP-04 | Usuário comum chama aprovar-usuario | 403 ou erro sem alteração | Pendente |
| SUP-05 | Admin aprova usuário | Status VERIFIED e auditoria criada | Pendente |
| SUP-06 | Inserção de auditoria falha | Não declarar aprovação auditada sem evidência | Pendente |
| SUP-07 | RLS perfis_update_self | Usuário não altera funcao/status arbitrariamente | Pendente |
| SUP-08 | RLS doacoes_read | Só status AVAILABLE visível a papéis permitidos | Pendente |
| SUP-09 | Documentos de outro usuário | Sem acesso horizontal por RLS/Storage | Pendente |
| SUP-10 | CORS e nome_arquivo malicioso | Rejeição/sanitização antes do upload | Pendente |
| SUP-11 | PostGIS para doações | Índice geography e consultas estáveis | Pendente |
| SUP-12 | Reaplicar migration em ambiente novo | Migrações determinísticas sem perda | Pendente |
| SUP-13 | Credencial service_role no client | Nenhuma ocorrência no bundle/frontend | Pendente |

## Estratégia e evidências
Separar testes unitários com dependências simuladas, integração em ambiente de desenvolvimento isolado e E2E com dados sintéticos. Para sistemas Supabase, validar RLS sob usuário comum versus administrador antes de ativar fluxos; para protótipo UX, não inferir backend pela UI. Registrar SHA do código, fixtures, versão de serviços, status e evidências, sem expor documentos, tokens ou dados reais.
