# FB-SUP-TST — Matriz de testes funcional e de segurança

**Versão:** 2.2.0 · **14/11/2026**. Resultados diferenciam CI executado de E2E planejado.

| Caso | Verificação | Evidência atual | Status |
| --- | --- | --- | --- |
| T-01 | ADMIN não permitido em cadastro público | tests/role-policy.test.ts | Unitário aprovado |
| T-02 | App metadata é fonte de autorização | tests/role-policy.test.ts | Unitário aprovado |
| T-03 | E-mail, CNPJ, senha, PDF inválidos | tests/role-policy.test.ts | Unitário aprovado |
| T-04 | Trigger não usa papel de user_metadata | tests/sql/test_profile_security.sh | PG isolado aprovado |
| T-05 | Usuário não edita papel/status/email | tests/sql/test_profile_security.sh | PG isolado aprovado |
| T-06 | Não acessa perfil alheio | tests/sql/test_profile_security.sh | PG isolado aprovado |
| T-07 | Não autoaprova organização | tests/sql/test_resource_security.sh | PG isolado aprovado |
| T-08 | Não verifica documento próprio | tests/sql/test_resource_security.sh | PG isolado aprovado |
| T-09 | Não publica/reivindica doação direto | tests/sql/test_resource_security.sh | PG isolado aprovado |
| T-10 | Edge Functions passam Deno check | .github/workflows/security-tests.yml | Aprovado |
| T-11 | Fluxo real de confirmação de e-mail | Auth/SMTP Supabase | Pendente |
| T-12 | Registro e upload real no Storage | Auth/Storage Supabase | Pendente |
| T-13 | Falha de upload, rollback e reconciliação | Teste E2E controlado | Pendente |
| T-14 | Aprovação+auditoria atômica | Banco real + cenários negativos | Pendente |
| T-15 | Regras RLS via JWT e PostgREST real | Staging próprio | Pendente |
| T-16 | Consulta geográfica PostGIS real | Staging próprio | Pendente |
| T-17 | Quotas e antiabuso | Testes controlados de carga | Pendente |
| T-18 | Credenciais e dados de documentos | Revisão de políticas Storage | Pendente |
| T-19 | Deploy para projeto autorizado, rollback | Environment protegido | Pendente |

### Como reproduzir o portão de CI
`role-policy`: Node 22 (testes de autorização, validação). `rls-security`: PostgreSQL 17 descartável com fixture de Auth reduzida + migração e testes SQL. `deno-edge-types`: Deno 2 check de ambos handlers. Resultado final da main: [43648545626](https://github.com/DanieldeAlmeida2024/FoodBridge-Core-Supabase/actions/runs/43648545626).

**Não executar os scripts SQL em produção.** A fixture cria roles e tabelas de simulação de Auth em um PostgreSQL descartável. Regras de acesso e integrações reais exigem ambiente Supabase próprio.
