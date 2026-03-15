-- Extensões
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- TABELA DE PERFIS
CREATE TABLE public.perfis (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  tipo_usuario TEXT NOT NULL CHECK (tipo_usuario IN (
    'Doador',
    'ONG',
    'Admin'
  )),
  cnpj TEXT UNIQUE NOT NULL,
  esta_verificado BOOLEAN DEFAULT FALSE,
  nome_completo TEXT,
  telefone TEXT,
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acesso ao próprio perfil" ON public.perfis
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Admin visualiza todos os perfis" ON public.perfis
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM public.perfis
      WHERE id = auth.uid() AND tipo_usuario = 'Admin'
    )
  );

-- TABELA DE DOAÇÕES
CREATE TABLE public.doacoes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  doador_id UUID REFERENCES public.perfis(id) NOT NULL,
  tipo_alimento TEXT NOT NULL,
  descricao TEXT,
  quantidade TEXT NOT NULL,
  data_validade TIMESTAMPTZ NOT NULL,
  coordenadas GEOGRAPHY(POINT) NOT NULL, -- Armazena Lat/Lng
  endereco TEXT NOT NULL,
  status TEXT DEFAULT 'DISPONIVEL' CHECK (status IN (
    'DISPONIVEL',
    'AGUARDANDO_APROVACAO',
    'APROVADO',
    'COLETADO',
    'EXPIRADO'
  )),
  ong_id UUID REFERENCES public.perfis(id), -- ONG que reivindicou
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_doacoes_geo ON public.doacoes USING GIST (coordenadas);

ALTER TABLE public.doacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Visualização de doações disponíveis" ON public.doacoes
  FOR SELECT USING (status = 'DISPONIVEL');

CREATE POLICY "Gestão da própria doação" ON public.doacoes
  FOR ALL USING (auth.uid() = doador_id);

CREATE POLICY "ONGs verificadas reivindicam doações" ON public.doacoes
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM public.perfis
      WHERE id = auth.uid() AND tipo_usuario = 'ONG' AND esta_verificado = TRUE
    )
  );

-- TABELA DE LOGS/AUDITORIA 
CREATE TABLE public.registros_auditoria (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  usuario_id UUID REFERENCES public.perfis(id),
  acao TEXT NOT NULL,
  id_alvo UUID,
  detalhes JSONB,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

-- AUTOMAÇÃO DE PERFIL (TRIGGER)
CREATE OR REPLACE FUNCTION public.gerar_perfil_automatico()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfis (id, email, tipo_usuario, cnpj, nome_completo)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>
      'tipo_usuario',
      'Doador'
    ),
    COALESCE(NEW.raw_user_meta_data->>
      'cnpj',
      '00000000000000'
    ),
    NEW.raw_user_meta_data->>
      'nome_completo'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_novo_usuario_auth
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.gerar_perfil_automatico();

-- BUSCA POR RAIO
CREATE OR REPLACE FUNCTION public.buscar_doacoes_proximas(
  lat_usuario FLOAT,
  lng_usuario FLOAT,
  raio_km FLOAT DEFAULT 10.0
)
RETURNS TABLE (
  id UUID,
  tipo_alimento TEXT,
  quantidade TEXT,
  data_validade TIMESTAMPTZ,
  endereco TEXT,
  distancia_km FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.tipo_alimento,
    d.quantidade,
    d.data_validade,
    d.endereco,
    ST_Distance(
      d.coordenadas,
      ST_SetSRID(ST_MakePoint(lng_usuario, lat_usuario), 4326)::geography
    ) / 1000 AS distancia_km
  FROM public.doacoes d
  WHERE d.status = 'DISPONIVEL'
    AND ST_DWithin(
      d.coordenadas,
      ST_SetSRID(ST_MakePoint(lng_usuario, lat_usuario), 4326)::geography,
      raio_km * 1000
    )
  ORDER BY distancia_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DOCUMENTOS DE VERIFICAÇÃO
INSERT INTO storage.buckets (id, name, public) VALUES ('documentos-verificacao', 'documentos-verificacao', false);

CREATE POLICY "Admin visualiza documentos" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'documentos-verificacao' AND
    EXISTS (SELECT 1 FROM public.perfis WHERE id = auth.uid() AND tipo_usuario = 'Admin')
  );

CREATE POLICY "Upload de documentos autenticado" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'documentos-verificacao');