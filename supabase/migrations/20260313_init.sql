-- =====================================================
-- EXTENSÕES
-- =====================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE status_organizacao AS ENUM (
'PENDING_DOCUMENTS','UNDER_REVIEW','VERIFIED','SUSPENDED','INACTIVE'
);

CREATE TYPE tipo_documento AS ENUM (
'CNPJ_PROOF','ADDRESS_PROOF','ID_DOCUMENT','LOCATION_PHOTO','ADDITIONAL'
);

CREATE TYPE status_documento AS ENUM ('PENDING','VERIFIED','REJECTED');

CREATE TYPE unidade_medida AS ENUM ('KG','LITER','UNIT','BOX','BATCH');

CREATE TYPE nivel_qualidade AS ENUM ('PREMIUM','STANDARD','GRADE_B','SALVAGE');

CREATE TYPE status_reivindicacao AS ENUM (
'PENDING','APPROVED','REJECTED','CANCELLED','COMPLETED'
);

CREATE TYPE status_solicitacao AS ENUM (
'OPEN','MATCHED','PARTIALLY_FULFILLED','FULFILLED','CANCELLED','EXPIRED'
);

CREATE TYPE status_coleta AS ENUM (
'SCHEDULED','CONFIRMED','IN_PROGRESS','COMPLETED','CANCELLED','NO_SHOW'
);

CREATE TYPE prioridade AS ENUM ('LOW','MEDIUM','HIGH','URGENT');

CREATE TYPE periodo AS ENUM ('DAILY','WEEKLY','MONTHLY','YEARLY');

CREATE TYPE tipo_notificacao AS ENUM (
'DONATION_CLAIMED','CLAIM_APPROVED','CLAIM_REJECTED',
'PICKUP_SCHEDULED','PICKUP_COMPLETED','MATCH_FOUND',
'DOCUMENT_VERIFIED','DOCUMENT_REJECTED','ACCOUNT_VERIFIED','SYSTEM_ALERT'
);

CREATE TYPE tipo_doacao AS ENUM (
'VEGETABLES','FRUITS','GRAINS','DAIRY','MEAT','PREPARED_FOOD',
'BAKERY','BEVERAGES','OTHER'
);

CREATE TYPE funcao_usuario AS ENUM (
'DONOR','PRODUCER','DISTRIBUTOR','NGO','ADMIN'
);

CREATE TYPE status_usuario AS ENUM (
'PENDING_VERIFICATION','VERIFIED','SUSPENDED','INACTIVE'
);

CREATE TYPE status_voluntario AS ENUM ('ACTIVE','INACTIVE','SUSPENDED');

CREATE TYPE status_doacao AS ENUM (
'DRAFT','PUBLISHED','AVAILABLE','PARTIALLY_CLAIMED',
'FULLY_CLAIMED','COMPLETED','EXPIRED','CANCELLED'
);

-- =====================================================
-- PERFIS
-- =====================================================

CREATE TABLE public.perfis (

id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

email text UNIQUE NOT NULL,

nome text,

telefone text,

funcao funcao_usuario NOT NULL,

status status_usuario NOT NULL DEFAULT 'PENDING_VERIFICATION',

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;

CREATE POLICY perfis_self_select
ON public.perfis
FOR SELECT
USING (auth.uid() = id);

CREATE POLICY perfis_admin_select
ON public.perfis
FOR SELECT
USING (
EXISTS (
SELECT 1
FROM public.perfis p
WHERE p.id = auth.uid()
AND p.funcao = 'ADMIN'
)
);

CREATE POLICY perfis_self_update
ON public.perfis
FOR UPDATE
USING (auth.uid() = id);

-- =====================================================
-- ORGANIZACOES
-- =====================================================

CREATE TABLE public.organizacoes (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

nome text NOT NULL,

cnpj text UNIQUE NOT NULL,

descricao text,

endereco jsonb NOT NULL,

telefone text,

email text NOT NULL,

website text,

status status_organizacao NOT NULL,

data_verificacao timestamptz,

responsavel_id uuid REFERENCES public.perfis(id),

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

ALTER TABLE public.organizacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY organizacoes_public_read
ON public.organizacoes
FOR SELECT
USING (true);

CREATE POLICY organizacoes_owner_manage
ON public.organizacoes
FOR ALL
USING (auth.uid() = responsavel_id);

-- =====================================================
-- DOCUMENTOS
-- =====================================================

CREATE TABLE public.documentos (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

usuario_id uuid REFERENCES public.perfis(id) NOT NULL,

tipo tipo_documento NOT NULL,

url text NOT NULL,

status status_documento NOT NULL DEFAULT 'PENDING',

upload_em timestamptz DEFAULT now(),

verificado_em timestamptz,

verificado_por uuid REFERENCES public.perfis(id),

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY documentos_owner
ON public.documentos
FOR ALL
USING (auth.uid() = usuario_id);

CREATE POLICY documentos_admin
ON public.documentos
FOR ALL
USING (
EXISTS (
SELECT 1
FROM public.perfis
WHERE id = auth.uid()
AND funcao = 'ADMIN'
)
);

-- =====================================================
-- DOACOES
-- =====================================================

CREATE TABLE public.doacoes (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

doador_id uuid REFERENCES public.perfis(id) NOT NULL,

tipo_alimento tipo_doacao NOT NULL,

descricao_alimento text,

quantidade numeric NOT NULL,

unidade unidade_medida NOT NULL,

data_validade timestamptz NOT NULL,

status status_doacao DEFAULT 'AVAILABLE',

localizacao jsonb NOT NULL,

inicio_janela_coleta timestamptz NOT NULL,

fim_janela_coleta timestamptz NOT NULL,

ong_reivindicadora_id uuid REFERENCES public.perfis(id),

criado_em timestamptz DEFAULT now(),

atualizado_em timestamptz DEFAULT now()

);

CREATE INDEX idx_doacoes_geo
ON public.doacoes
USING GIST(
ST_SetSRID(
ST_MakePoint(
(localizacao->>'longitude')::float,
(localizacao->>'latitude')::float
),4326)::geography
);

ALTER TABLE public.doacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY doacoes_public
ON public.doacoes
FOR SELECT
USING (status='AVAILABLE');

CREATE POLICY doacoes_doador
ON public.doacoes
FOR ALL
USING (auth.uid() = doador_id);

-- =====================================================
-- AUDITORIA
-- =====================================================

CREATE TABLE public.registros_auditoria (

id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

usuario_id uuid REFERENCES public.perfis(id),

acao text NOT NULL,

id_alvo uuid,

detalhes jsonb,

criado_em timestamptz DEFAULT now()

);

ALTER TABLE public.registros_auditoria ENABLE ROW LEVEL SECURITY;

CREATE POLICY auditoria_admin
ON public.registros_auditoria
FOR SELECT
USING (
EXISTS(
SELECT 1 FROM public.perfis
WHERE id = auth.uid()
AND funcao = 'ADMIN'
)
);

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

CREATE TRIGGER tr_novo_usuario_auth
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.gerar_perfil_automatico();

-- =====================================================
-- BUSCA GEO
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

LANGUAGE plpgsql
AS $$

BEGIN

RETURN QUERY

SELECT

d.id,
d.tipo_alimento,
d.quantidade,
d.unidade,
d.data_validade,
d.localizacao,

ST_Distance(

ST_SetSRID(ST_MakePoint(
(d.localizacao->>'longitude')::float,
(d.localizacao->>'latitude')::float
),4326)::geography,

ST_SetSRID(ST_MakePoint(
lng_usuario,
lat_usuario
),4326)::geography

)/1000

FROM public.doacoes d

WHERE d.status='AVAILABLE'

AND ST_DWithin(

ST_SetSRID(ST_MakePoint(
(d.localizacao->>'longitude')::float,
(d.localizacao->>'latitude')::float
),4326)::geography,

ST_SetSRID(ST_MakePoint(
lng_usuario,
lat_usuario
),4326)::geography,

raio_km*1000

)

ORDER BY 7;

END;
$$;

-- =====================================================
-- STORAGE
-- =====================================================

INSERT INTO storage.buckets (id,name,public)
VALUES ('documentos-verificacao','documentos-verificacao',false)
ON CONFLICT (id) DO NOTHING;
