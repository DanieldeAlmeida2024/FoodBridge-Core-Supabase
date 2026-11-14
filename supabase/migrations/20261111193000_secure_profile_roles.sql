-- FoodBridge Core — P0: autoridade dos perfis e trigger de onboarding
-- 2026-11-11 | Não executar contra outros projetos Supabase.
-- Aplicação exige inspeção prévia das permissões existentes e backup.
-- A migração NÃO promove nem rebaixa automaticamente administradores legados.

BEGIN;

-- RLS controla LINHAS. Grants de COLUNAS controlam o que o cliente pode editar.
-- A política antiga de UPDATE sem privilégios de coluna deixava funcao/status mutáveis.
ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS perfis_update_self ON public.perfis;
DROP POLICY IF EXISTS perfis_update_public_fields ON public.perfis;

CREATE POLICY perfis_update_public_fields
ON public.perfis
FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = id)
WITH CHECK ((SELECT auth.uid()) = id);

-- Retira permissões que possam ter sido entregues por migrações/GRANTs anteriores.
REVOKE ALL ON TABLE public.perfis FROM PUBLIC, anon, authenticated;

-- O titular pode ler a própria linha (perfis_select_self) e editar SOMENTE nome/telefone.
-- Papel, status, id e email ficam exclusivamente sob operações privilegiadas auditadas.
GRANT SELECT ON TABLE public.perfis TO authenticated;
GRANT UPDATE (nome, telefone) ON TABLE public.perfis TO authenticated;

-- O trigger Auth deve ler autoridade somente de raw_app_meta_data.
-- raw_user_meta_data é editável pelo titular; não pode conferir privilégio ADMIN.
-- search_path fixo evita resolução de objetos controlados pelo solicitante.
CREATE OR REPLACE FUNCTION public.gerar_perfil_automatico()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $foodbridge$
BEGIN
    INSERT INTO public.perfis (id, email, nome, telefone, funcao)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data ->> 'nome_completo',
        NEW.raw_user_meta_data ->> 'telefone',
        CASE
            WHEN (NEW.raw_app_meta_data ->> 'tipo_usuario')
                 IN ('DONOR', 'PRODUCER', 'DISTRIBUTOR', 'NGO', 'ADMIN')
            THEN (NEW.raw_app_meta_data ->> 'tipo_usuario')::public.funcao_usuario
            ELSE 'DONOR'::public.funcao_usuario
        END
    );
    RETURN NEW;
END;
$foodbridge$;

-- Esta função SECURITY DEFINER é acionada por trigger, não por RPC pública.
REVOKE ALL ON FUNCTION public.gerar_perfil_automatico() FROM PUBLIC, anon, authenticated;

-- GRANTS de coluna são obrigatórios: policy RLS protege a linha, não o status.
-- Organizações: titular não consegue aprovar a própria organização.
ALTER TABLE public.organizacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizacoes ALTER COLUMN status SET DEFAULT 'PENDING_DOCUMENTS'::public.status_organizacao;
DROP POLICY IF EXISTS organizacoes_read ON public.organizacoes;
DROP POLICY IF EXISTS organizacoes_owner ON public.organizacoes;
DROP POLICY IF EXISTS organizacoes_insert_owner ON public.organizacoes;
DROP POLICY IF EXISTS organizacoes_update_owner ON public.organizacoes;
CREATE POLICY organizacoes_read ON public.organizacoes FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = responsavel_id OR status = 'VERIFIED');
CREATE POLICY organizacoes_insert_owner ON public.organizacoes FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) = responsavel_id AND status = 'PENDING_DOCUMENTS');
CREATE POLICY organizacoes_update_owner ON public.organizacoes FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = responsavel_id)
WITH CHECK ((SELECT auth.uid()) = responsavel_id);
REVOKE ALL ON TABLE public.organizacoes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.organizacoes TO authenticated;
GRANT INSERT (nome, cnpj, descricao, endereco, telefone, email, website, responsavel_id)
ON public.organizacoes TO authenticated;
GRANT UPDATE (nome, descricao, endereco, telefone, email, website)
ON public.organizacoes TO authenticated;

-- Documentos: verificação e aprovação pertencem exclusivamente ao serviço.
ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS documentos_owner ON public.documentos;
DROP POLICY IF EXISTS documentos_read_owner ON public.documentos;
CREATE POLICY documentos_read_owner ON public.documentos FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = usuario_id);
REVOKE ALL ON TABLE public.documentos FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.documentos TO authenticated;

-- Doações: dono só cria/edita rascunho; publicação, reivindicação e status
-- dependem de serviço transacional autorizado ainda não entregue neste backend.
ALTER TABLE public.doacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doacoes ALTER COLUMN status SET DEFAULT 'DRAFT'::public.status_doacao;
DROP POLICY IF EXISTS doacoes_read ON public.doacoes;
DROP POLICY IF EXISTS doacoes_owner ON public.doacoes;
DROP POLICY IF EXISTS doacoes_insert_owner ON public.doacoes;
DROP POLICY IF EXISTS doacoes_update_draft_owner ON public.doacoes;
CREATE POLICY doacoes_read ON public.doacoes FOR SELECT TO authenticated
USING (status = 'AVAILABLE' OR (SELECT auth.uid()) = doador_id);
CREATE POLICY doacoes_insert_owner ON public.doacoes FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) = doador_id AND status = 'DRAFT');
CREATE POLICY doacoes_update_draft_owner ON public.doacoes FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = doador_id AND status = 'DRAFT')
WITH CHECK ((SELECT auth.uid()) = doador_id AND status = 'DRAFT');
REVOKE ALL ON TABLE public.doacoes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.doacoes TO authenticated;
GRANT INSERT (doador_id, tipo_alimento, descricao_alimento, quantidade, unidade,
 data_validade, localizacao, geo, inicio_janela_coleta, fim_janela_coleta)
ON public.doacoes TO authenticated;
GRANT UPDATE (tipo_alimento, descricao_alimento, quantidade, unidade, data_validade,
 localizacao, geo, inicio_janela_coleta, fim_janela_coleta)
ON public.doacoes TO authenticated;

-- Funções legadas de busca devem obedecer à RLS do chamador (e não bypass).
DO $guard$
BEGIN
  IF to_regprocedure('public.get_nearby_donations(double precision,double precision,double precision)') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.get_nearby_donations(double precision,double precision,double precision) SECURITY INVOKER';
    EXECUTE 'REVOKE ALL ON FUNCTION public.get_nearby_donations(double precision,double precision,double precision) FROM PUBLIC, anon';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_nearby_donations(double precision,double precision,double precision) TO authenticated';
  END IF;
  IF to_regprocedure('public.buscar_doacoes_proximas(double precision,double precision,double precision)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.buscar_doacoes_proximas(double precision,double precision,double precision) FROM PUBLIC, anon';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.buscar_doacoes_proximas(double precision,double precision,double precision) TO authenticated';
  END IF;
END;
$guard$;

COMMIT;

-- IMPORTANTE: linhas ADMIN existentes podem ter origem em metadata antiga não confiável.
-- Antes do deploy da Edge Function, revisar manualmente essas contas e sua app_metadata.
-- Consulta somente leitura sugerida (não incluída como alteração nesta migração):
-- SELECT p.id, p.funcao, p.status, u.raw_app_meta_data ->> 'tipo_usuario' AS papel_confiavel
-- FROM public.perfis AS p JOIN auth.users AS u ON u.id = p.id
-- WHERE p.funcao = 'ADMIN';
