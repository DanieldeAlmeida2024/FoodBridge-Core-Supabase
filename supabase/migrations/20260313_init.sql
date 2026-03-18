-- =====================================================
-- EXTENSIONS
-- =====================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- ENUM TYPES (idempotent)
-- =====================================================

DO $$ BEGIN
CREATE TYPE funcao_usuario AS ENUM ('DONOR','PRODUCER','DISTRIBUTOR','NGO','ADMIN');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
CREATE TYPE status_usuario AS ENUM ('PENDING_VERIFICATION','VERIFIED','SUSPENDED','INACTIVE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
CREATE TYPE status_organizacao AS ENUM ('PENDING_DOCUMENTS','UNDER_REVIEW','VERIFIED','SUSPENDED','INACTIVE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
CREATE TYPE tipo_documento AS ENUM ('CNPJ_PROOF','ADDRESS_PROOF','ID_DOCUMENT','LOCATION_PHOTO','ADDITIONAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
CREATE TYPE status_documento AS ENUM ('PENDING','VERIFIED','REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
CREATE TYPE unidade_medida AS ENUM ('KG','LITER','UNIT','BOX','BATCH');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
CREATE TYPE tipo_doacao AS ENUM ('VEGETABLES','FRUITS','GRAINS','DAIRY','MEAT','PREPARED_FOOD','BAKERY','BEVERAGES','OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
CREATE TYPE status_doacao AS ENUM ('DRAFT','PUBLISHED','AVAILABLE','PARTIALLY_CLAIMED','FULLY_CLAIMED','COMPLETED','EXPIRED','CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =====================================================
-- PERFIS
-- =====================================================

CREATE TABLE IF NOT EXISTS public.perfis (

id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

email text UNIQUE NOT NULL,

nome text,

telefone text,

funcao funcao_usuario NOT NULL,

status status_usuario DEFAULT 'PENDING_VERIFICATION',

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS perfis_select_self ON public.perfis;
CREATE POLICY perfis_select_self
ON public.perfis
FOR SELECT
USING (auth.uid() = id);

DROP POLICY IF EXISTS perfis_update_self ON public.perfis;
CREATE POLICY perfis_update_self
ON public.perfis
FOR UPDATE
USING (auth.uid() = id);

-- =====================================================
-- ORGANIZACOES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.organizacoes (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

nome text NOT NULL,

cnpj text UNIQUE NOT NULL,

descricao text,

endereco jsonb NOT NULL,

telefone text,

email text NOT NULL,

website text,

status status_organizacao,

data_verificacao timestamptz,

responsavel_id uuid REFERENCES public.perfis(id),

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

ALTER TABLE public.organizacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS organizacoes_read ON public.organizacoes;
CREATE POLICY organizacoes_read
ON public.organizacoes
FOR SELECT
USING (true);

DROP POLICY IF EXISTS organizacoes_owner ON public.organizacoes;
CREATE POLICY organizacoes_owner
ON public.organizacoes
FOR ALL
USING (auth.uid() = responsavel_id);

-- =====================================================
-- DOCUMENTOS
-- =====================================================

CREATE TABLE IF NOT EXISTS public.documentos (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

usuario_id uuid REFERENCES public.perfis(id),

tipo tipo_documento,

url text NOT NULL,

status status_documento DEFAULT 'PENDING',

upload_em timestamptz DEFAULT now(),

verificado_em timestamptz,

verificado_por uuid REFERENCES public.perfis(id),

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS documentos_owner ON public.documentos;
CREATE POLICY documentos_owner
ON public.documentos
FOR ALL
USING (auth.uid() = usuario_id);

-- =====================================================
-- DOACOES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.doacoes (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

doador_id uuid REFERENCES public.perfis(id),

tipo_alimento tipo_doacao,

descricao_alimento text,

quantidade numeric NOT NULL,

unidade unidade_medida NOT NULL,

data_validade timestamptz NOT NULL,

status status_doacao DEFAULT 'AVAILABLE',

localizacao jsonb NOT NULL,

geo geography(Point,4326),

inicio_janela_coleta timestamptz,

fim_janela_coleta timestamptz,

ong_reivindicadora_id uuid REFERENCES public.perfis(id),

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

CREATE INDEX IF NOT EXISTS idx_doacoes_geo
ON public.doacoes
USING GIST (geo);

ALTER TABLE public.doacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS doacoes_read ON public.doacoes;
CREATE POLICY doacoes_read
ON public.doacoes
FOR SELECT
USING (status='AVAILABLE');

DROP POLICY IF EXISTS doacoes_owner ON public.doacoes;
CREATE POLICY doacoes_owner
ON public.doacoes
FOR ALL
USING (auth.uid() = doador_id);

-- =====================================================
-- AUDITORIA
-- =====================================================

CREATE TABLE IF NOT EXISTS public.registros_auditoria (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

usuario_id uuid REFERENCES public.perfis(id),

acao text NOT NULL,

id_alvo uuid,

detalhes jsonb,

criado_em timestamptz DEFAULT now()

);

ALTER TABLE public.registros_auditoria ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- TRIGGER PERFIL AUTOMATICO
-- =====================================================

CREATE OR REPLACE FUNCTION public.gerar_perfil_automatico()

RETURNS trigger

LANGUAGE plpgsql

SECURITY DEFINER

AS $$

BEGIN

INSERT INTO public.perfis
(id,email,nome,telefone,funcao)

VALUES
(
NEW.id,
NEW.email,
NEW.raw_user_meta_data->>'nome_completo',
NEW.raw_user_meta_data->>'telefone',
COALESCE(
(NEW.raw_user_meta_data->>'tipo_usuario')::funcao_usuario,
'DONOR'
)
);

RETURN NEW;

END;

$$;

DROP TRIGGER IF EXISTS tr_novo_usuario_auth ON auth.users;

CREATE TRIGGER tr_novo_usuario_auth

AFTER INSERT ON auth.users

FOR EACH ROW

EXECUTE FUNCTION public.gerar_perfil_automatico();

-- =====================================================
-- GEO SEARCH FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.buscar_doacoes_proximas(

lat_usuario float,
lng_usuario float,
raio_km float DEFAULT 10

)

RETURNS TABLE(

id uuid,
tipo_alimento tipo_doacao,
quantidade numeric,
unidade unidade_medida,
data_validade timestamptz,
endereco jsonb,
distancia_km float

)

LANGUAGE sql

AS $$

SELECT

d.id,
d.tipo_alimento,
d.quantidade,
d.unidade,
d.data_validade,
d.localizacao,

ST_Distance(
d.geo,
ST_SetSRID(ST_MakePoint(lng_usuario,lat_usuario),4326)::geography
)/1000 AS distancia_km

FROM public.doacoes d

WHERE d.status='AVAILABLE'

AND ST_DWithin(
d.geo,
ST_SetSRID(ST_MakePoint(lng_usuario,lat_usuario),4326)::geography,
raio_km*1000
)

ORDER BY distancia_km;

$$;

-- =====================================================
-- STORAGE BUCKET
-- =====================================================

INSERT INTO storage.buckets (id,name,public)

VALUES ('documentos-verificacao','documentos-verificacao',false)

ON CONFLICT (id) DO NOTHING;