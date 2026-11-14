-- Fixture isolada para validar a migração de hardening. NÃO é o schema completo Supabase.
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE SCHEMA auth;
CREATE TABLE auth.users (
    id uuid PRIMARY KEY,
    email text NOT NULL,
    raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
    raw_app_meta_data jsonb DEFAULT '{}'::jsonb
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
CREATE TYPE public.funcao_usuario AS ENUM ('DONOR','PRODUCER','DISTRIBUTOR','NGO','ADMIN');
CREATE TYPE public.status_usuario AS ENUM ('PENDING_VERIFICATION','VERIFIED','SUSPENDED','INACTIVE');
CREATE TABLE public.perfis (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE NOT NULL,
    nome text,
    telefone text,
    funcao public.funcao_usuario NOT NULL,
    status public.status_usuario DEFAULT 'PENDING_VERIFICATION',
    criado_em timestamptz DEFAULT now(),
    atualizado_em timestamptz DEFAULT now()
);
ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;
CREATE POLICY perfis_select_self ON public.perfis FOR SELECT USING (auth.uid() = id);
CREATE POLICY perfis_update_self ON public.perfis FOR UPDATE USING (auth.uid() = id);
GRANT ALL ON TABLE public.perfis TO authenticated;

-- Replicação mínima da vulnerabilidade anterior para provar que o patch a substitui.
CREATE FUNCTION public.gerar_perfil_automatico()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.perfis(id,email,nome,telefone,funcao)
    VALUES (NEW.id,NEW.email,NEW.raw_user_meta_data->>'nome_completo',
            NEW.raw_user_meta_data->>'telefone',
            COALESCE((NEW.raw_user_meta_data->>'tipo_usuario')::public.funcao_usuario,
                'DONOR'::public.funcao_usuario));
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_novo_usuario_auth AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.gerar_perfil_automatico();

-- Recursos resumidos somente para testes de RLS/grants (sem PostGIS/Supabase remoto).
CREATE TYPE public.status_organizacao AS ENUM ('PENDING_DOCUMENTS','UNDER_REVIEW','VERIFIED','SUSPENDED','INACTIVE');
CREATE TYPE public.status_documento AS ENUM ('PENDING','VERIFIED','REJECTED');
CREATE TYPE public.status_doacao AS ENUM ('DRAFT','PUBLISHED','AVAILABLE','PARTIALLY_CLAIMED','FULLY_CLAIMED','COMPLETED','EXPIRED','CANCELLED');
CREATE TYPE public.tipo_doacao AS ENUM ('VEGETABLES','FRUITS','GRAINS','DAIRY','MEAT','PREPARED_FOOD','BAKERY','BEVERAGES','OTHER');
CREATE TYPE public.unidade_medida AS ENUM ('KG','LITER','UNIT','BOX','BATCH');
CREATE TYPE public.tipo_documento AS ENUM ('CNPJ_PROOF','ADDRESS_PROOF','ID_DOCUMENT','LOCATION_PHOTO','ADDITIONAL');
CREATE TABLE public.organizacoes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), nome text NOT NULL, cnpj text UNIQUE NOT NULL,
 descricao text, endereco jsonb NOT NULL, telefone text, email text NOT NULL, website text,
 status public.status_organizacao, responsavel_id uuid REFERENCES public.perfis(id)
);
ALTER TABLE public.organizacoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY organizacoes_read ON public.organizacoes FOR SELECT USING (true);
CREATE POLICY organizacoes_owner ON public.organizacoes FOR ALL USING (auth.uid() = responsavel_id);
GRANT ALL ON TABLE public.organizacoes TO authenticated;
CREATE TABLE public.documentos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), usuario_id uuid REFERENCES public.perfis(id),
 tipo public.tipo_documento, url text NOT NULL, status public.status_documento DEFAULT 'PENDING',
 verificado_em timestamptz, verificado_por uuid REFERENCES public.perfis(id)
);
ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;
CREATE POLICY documentos_owner ON public.documentos FOR ALL USING (auth.uid() = usuario_id);
GRANT ALL ON TABLE public.documentos TO authenticated;
CREATE TABLE public.doacoes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), doador_id uuid REFERENCES public.perfis(id),
 tipo_alimento public.tipo_doacao, descricao_alimento text, quantidade numeric NOT NULL,
 unidade public.unidade_medida NOT NULL, data_validade timestamptz NOT NULL,
 status public.status_doacao DEFAULT 'AVAILABLE', localizacao jsonb NOT NULL,
 geo text, inicio_janela_coleta timestamptz, fim_janela_coleta timestamptz,
 ong_reivindicadora_id uuid REFERENCES public.perfis(id)
);
ALTER TABLE public.doacoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY doacoes_read ON public.doacoes FOR SELECT USING (status = 'AVAILABLE');
CREATE POLICY doacoes_owner ON public.doacoes FOR ALL USING (auth.uid() = doador_id);
GRANT ALL ON TABLE public.doacoes TO authenticated;
