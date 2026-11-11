# FoodBridge Core — projeto Supabase/PostGIS

> **FBS-DOC v1.0.0** | 11/11/2026 | commit `141f2c60b4d6f55768ca99c2d268f766165dc9c0` | inspeção estática, sem acesso ao ambiente hospedado.


## Estrutura real
Implementação alternativa do domínio FoodBridge usando **Supabase Auth**, tabelas PostgreSQL com RLS, PostGIS para proximidade, Storage privado para documentos e Edge Functions Deno. Esta base não deve ser confundida automaticamente com o backend Kotlin em Oracle Cloud; são tecnologias e modelos de dados distintos.

`supabase/migrations/20260313_init.sql` cria extensões `postgis` e `pgcrypto`, enums de papéis (DONOR/PRODUCER/DISTRIBUTOR/NGO/ADMIN), status, documentos, unidades e doações. As tabelas identificadas são `perfis`, `organizacoes`, `documentos`, `doacoes` e `registros_auditoria`; todas possuem RLS habilitada no script. `supabase/migrations/20260314_zgeo_config.sql` adiciona RPC de busca geográfica e triggers de `atualizado_em`.

## Fluxos de funções
- `supabase/functions/registrar-usuario/index.ts` usa `SUPABASE_SERVICE_ROLE_KEY`, cria usuário Auth com `user_metadata`, limpa CNPJ, faz upload de PDF em `documentos-verificacao` e retorna 201.
- Trigger `gerar_perfil_automatico()` lê `raw_user_meta_data.tipo_usuario` para definir `public.perfis.funcao`. **Risco crítico:** campos de user_metadata são controláveis pelo cliente em alguns fluxos; a enum inclui `ADMIN`. Deve-se impedir autoatribuição de privilégios antes de publicação.
- `aprovar-usuario/index.ts` consulta usuário via token, confere `perfis.funcao==='ADMIN'` e usa client de service role para alterar status e gravar `registros_auditoria`.
- `get_nearby_donations()` é definida `SECURITY DEFINER` no schema `public`, com consulta às doações por coordenada e raio. Isso pode contornar RLS e exige revisão de `EXECUTE`, `search_path` e validação/autorização.
- RLS `organizacoes_read` usa `USING(true)`; revisar se todo campo pode realmente ser consultado anonimamente. `perfis_update_self` não apresenta `WITH CHECK` explícito no snapshot.
- Bucket `documentos-verificacao` é criado com `public=false`; revisar políticas de Storage antes de permitir downloads e uploads.

## Dependências e versionamento de banco
Arquivos SQL de migração representam histórico de schema; **não editar migrações já aplicadas** nem executar no projeto hospedado sem diagnóstico. `.github/workflows/deploy-functions.yml` representa deploy de Edge Functions distinto do CI do backend Kotlin. As pastas `supabase/.temp/` são artefatos locais e não devem orientar ambientes de produção.

## Política de segurança para esta revisão
Não executar SQL contra projeto remoto, não usar chave service_role em frontend, e não copiar configurações reais para GitHub. A documentação identifica riscos, mas não os corrige automaticamente. Referência técnica adicional: https://supabase.com/docs/guides/database/postgres/row-level-security .
