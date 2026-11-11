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
