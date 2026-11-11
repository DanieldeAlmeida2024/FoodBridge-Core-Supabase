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

COMMIT;

-- IMPORTANTE: linhas ADMIN existentes podem ter origem em metadata antiga não confiável.
-- Antes do deploy da Edge Function, revisar manualmente essas contas e sua app_metadata.
-- Consulta somente leitura sugerida (não incluída como alteração nesta migração):
-- SELECT p.id, p.funcao, p.status, u.raw_app_meta_data ->> 'tipo_usuario' AS papel_confiavel
-- FROM public.perfis AS p JOIN auth.users AS u ON u.id = p.id
-- WHERE p.funcao = 'ADMIN';
