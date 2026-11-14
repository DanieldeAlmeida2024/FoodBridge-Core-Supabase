# FB-SUP-PROJ — Arquitetura e escopo do FoodBridge Core Supabase

**Versão documental 2.2.0** · 14/11/2026 · código na main: `f6cbd34389ef421634f110d06e6a26510616c6dd`.

## Problema e recorte
Backend *alternativo* para conexão de doadores/organizações e gestão de alimentos, usando Supabase Auth, PostgreSQL/PostGIS, Storage e Edge Functions. Não compartilhar credenciais nem infraestrutura com a API Kotlin. Não há instância Supabase FoodBridge confirmada nos projetos conectados.

## Domínio observado
- `perfis`: id referenciando Auth, papel DONOR/PRODUCER/DISTRIBUTOR/NGO/ADMIN, status de verificação.
- `organizacoes`: responsável, CNPJ e estado; criadas pendentes, publicação de status somente por serviço privilegiado.
- `documentos`: registro e status de verificação; leitura restrita ao titular, escrita por serviço.
- `doacoes`: alimento, quantidade, unidade, validade, localização/geografia, status e reivindicação; cliente cria e edita rascunhos.
- `registros_auditoria`: histórico de decisões administrativas, ainda sem operação transacional atômica.

## Fronteiras
`registrar-usuario` valida papel permitido e entrada, cria Auth e envia documento PDF com caminho baseado em UUID; falha de upload tenta compensação. O trigger de perfil confia em `raw_app_meta_data`, não `raw_user_meta_data`. `aprovar-usuario` exige token validado, papel ADMIN em `app_metadata` e perfil ADMIN/VERIFIED.

A migration incremental `20261111193000_secure_profile_roles.sql` define RLS por proprietário, grants explícitos por coluna e consulta geográfica invoker; teste PostgreSQL descartável passou. **Migração não aplicada em Supabase hospedado**.

## Integração e operação
Workflow de deploy somente manual exige ambiente `foodbridge-supabase-production` e refs coerentes. Nenhum deploy automático de Edge Functions; nenhuma publicação/remodelagem de banco sem identificação, backup e autorização do projeto FoodBridge correto.

## Decisões não concluídas
Confirmação real de e-mail (o legado ainda usa `email_confirm: true`), CAPTCHA/rate limit, análise antivírus/retenção de documentos, atomicidade de aprovação+auditoria, testes de PostgREST/Auth/Storage/PostGIS reais e monitoramento operacional. A ausência de testes E2E bloqueia produção.

Referências: [riscos](RISCOS.md) · [testes](../testes/PLANO_DE_TESTES.md) · [UML](../uml/README.md) · [hardening](../seguranca/PERFIS_AUTORIZACAO.md).
