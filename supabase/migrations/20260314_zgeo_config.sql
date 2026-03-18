-- =====================================================
-- FUNÇÃO GEO: BUSCAR DOAÇÕES PRÓXIMAS
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_nearby_donations(

user_lat FLOAT,
user_lng FLOAT,
radius_km FLOAT DEFAULT 10.0

)

RETURNS TABLE (

id UUID,
doador_id UUID,
tipo_alimento TEXT,
descricao TEXT,
quantidade NUMERIC,
data_validade TIMESTAMPTZ,
endereco JSONB,
status TEXT,
distance_km FLOAT

)

LANGUAGE sql

SECURITY DEFINER

AS $$

SELECT

d.id,
d.doador_id,
d.tipo_alimento::TEXT,
d.descricao_alimento,
d.quantidade,
d.data_validade,
d.localizacao,
d.status::TEXT,

ST_Distance(
d.geo,
ST_SetSRID(ST_MakePoint(user_lng,user_lat),4326)::geography
)/1000 AS distance_km

FROM public.doacoes d

WHERE d.status = 'AVAILABLE'

AND ST_DWithin(
d.geo,
ST_SetSRID(ST_MakePoint(user_lng,user_lat),4326)::geography,
radius_km * 1000
)

ORDER BY distance_km;

$$;



-- =====================================================
-- FUNÇÃO PARA ATUALIZAR TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()

RETURNS trigger

LANGUAGE plpgsql

AS $$

BEGIN
NEW.atualizado_em = now();
RETURN NEW;
END;

$$;



-- =====================================================
-- TRIGGERS UPDATED_AT
-- =====================================================

DROP TRIGGER IF EXISTS set_perfis_updated_at ON public.perfis;

CREATE TRIGGER set_perfis_updated_at

BEFORE UPDATE ON public.perfis

FOR EACH ROW

EXECUTE FUNCTION public.handle_updated_at();



DROP TRIGGER IF EXISTS set_doacoes_updated_at ON public.doacoes;

CREATE TRIGGER set_doacoes_updated_at

BEFORE UPDATE ON public.doacoes

FOR EACH ROW

EXECUTE FUNCTION public.handle_updated_at();