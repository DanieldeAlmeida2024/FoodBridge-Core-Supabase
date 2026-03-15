-- Extensões necessárias para funcionalidades geoespaciais e UUIDs.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Definição dos Tipos ENUM (conforme diagrama de classes e enums fornecidos)
CREATE TYPE public.status_organizacao AS ENUM (
  'PENDING_DOCUMENTS',
  'UNDER_REVIEW',
  'VERIFIED',
  'SUSPENDED',
  'INACTIVE'
);

CREATE TYPE public.tipo_documento AS ENUM (
  'CNPJ_PROOF',
  'ADDRESS_PROOF',
  'ID_DOCUMENT',
  'LOCATION_PHOTO',
  'ADDITIONAL'
);

CREATE TYPE public.status_documento AS ENUM (
  'PENDING',
  'VERIFIED',
  'REJECTED'
);

CREATE TYPE public.unidade_medida AS ENUM (
  'KG',
  'LITER',
  'UNIT',
  'BOX',
  'BATCH'
);

CREATE TYPE public.nivel_qualidade AS ENUM (
  'PREMIUM',
  'STANDARD',
  'GRADE_B',
  'SALVAGE'
);

CREATE TYPE public.status_reivindicacao AS ENUM (
  'PENDING',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
  'COMPLETED'
);

CREATE TYPE public.status_solicitacao AS ENUM (
  'OPEN',
  'MATCHED',
  'PARTIALLY_FULFILLED',
  'FULFILLED',
  'CANCELLED',
  'EXPIRED'
);

CREATE TYPE public.status_coleta AS ENUM (
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW'
);

CREATE TYPE public.prioridade AS ENUM (
  'LOW',
  'MEDIUM',
  'HIGH',
  'URGENT'
);

CREATE TYPE public.periodo AS ENUM (
  'DAILY',
  'WEEKLY',
  'MONTHLY',
  'YEARLY'
);

CREATE TYPE public.tipo_notificacao AS ENUM (
  'DONATION_CLAIMED',
  'CLAIM_APPROVED',
  'CLAIM_REJECTED',
  'PICKUP_SCHEDULED',
  'PICKUP_COMPLETED',
  'MATCH_FOUND',
  'DOCUMENT_VERIFIED',
  'DOCUMENT_REJECTED',
  'ACCOUNT_VERIFIED',
  'SYSTEM_ALERT'
);

CREATE TYPE public.tipo_doacao AS ENUM (
  'VEGETABLES',
  'FRUITS',
  'GRAINS',
  'DAIRY',
  'MEAT',
  'PREPARED_FOOD',
  'BAKERY',
  'BEVERAGES',
  'OTHER'
);

CREATE TYPE public.funcao_usuario AS ENUM (
  'DONOR',
  'PRODUCER',
  'DISTRIBUTOR',
  'NGO',
  'ADMIN'
);

CREATE TYPE public.status_usuario AS ENUM (
  'PENDING_VERIFICATION',
  'VERIFIED',
  'SUSPENDED',
  'INACTIVE'
);

CREATE TYPE public.status_voluntario AS ENUM (
  'ACTIVE',
  'INACTIVE',
  'SUSPENDED'
);

CREATE TYPE public.status_doacao AS ENUM (
  'DRAFT',
  'PUBLISHED',
  'AVAILABLE',
  'PARTIALLY_CLAIMED',
  'FULLY_CLAIMED',
  'COMPLETED',
  'EXPIRED',
  'CANCELLED'
);

-- 1. TABELA DE PERFIS
-- Estende a tabela auth.users do Supabase para adicionar informações de perfil.
CREATE TABLE public.perfis (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  nome TEXT, 
  telefone TEXT, 
  funcao funcao_usuario NOT NULL, 
  status status_usuario NOT NULL DEFAULT 'PENDING_VERIFICATION', 
  criado_em TIMESTAMPTZ DEFAULT NOW(), 
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Perfis: Acesso ao próprio perfil" ON public.perfis
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Perfis: Admin visualiza todos os perfis" ON public.perfis
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.perfis WHERE id = auth.uid() AND funcao = 'ADMIN')
  );

CREATE POLICY "Perfis: Usuários podem atualizar seu próprio perfil" ON public.perfis
  FOR UPDATE USING (auth.uid() = id);

-- 2. TABELA DE ORGANIZAÇÕES
CREATE TABLE public.organizacoes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nome TEXT NOT NULL,
  cnpj TEXT UNIQUE NOT NULL,
  descricao TEXT, 
  endereco JSONB NOT NULL, 
  telefone TEXT,
  email TEXT NOT NULL, 
  website TEXT, 
  status status_organizacao NOT NULL, 
  data_verificacao TIMESTAMPTZ, 
  criado_em TIMESTAMPTZ DEFAULT NOW(), 
  atualizado_em TIMESTAMPTZ DEFAULT NOW(), 
  responsavel_id UUID REFERENCES public.perfis(id) 
);

ALTER TABLE public.organizacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Organizacoes: Acesso de leitura para todos" ON public.organizacoes
  FOR SELECT USING (TRUE);

CREATE POLICY "Organizacoes: Donos podem gerenciar" ON public.organizacoes
  FOR ALL USING (auth.uid() = responsavel_id);

-- 3. TABELA DE DOCUMENTOS
CREATE TABLE public.documentos (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  usuario_id UUID REFERENCES public.perfis(id) NOT NULL, 
  tipo tipo_documento NOT NULL, 
  url TEXT NOT NULL, 
  status status_documento NOT NULL DEFAULT 'PENDING', 
  upload_em TIMESTAMPTZ DEFAULT NOW(), 
  verificado_em TIMESTAMPTZ, 
  verificado_por UUID REFERENCES public.perfis(id), 
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Documentos: Acesso ao próprio documento" ON public.documentos
  FOR ALL USING (auth.uid() = usuario_id);

CREATE POLICY "Documentos: Admin pode gerenciar todos os documentos" ON public.documentos
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.perfis WHERE id = auth.uid() AND funcao = 'ADMIN')
  );

-- 4. TABELA DE DOAÇÕES
CREATE TABLE public.doacoes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  doador_id UUID REFERENCES public.perfis(id) NOT NULL, 
  tipo_alimento tipo_doacao NOT NULL, 
  descricao_alimento TEXT, 
  quantidade DECIMAL NOT NULL, 
  unidade unidade_medida NOT NULL, 
  data_validade TIMESTAMPTZ NOT NULL, 
  status status_doacao NOT NULL DEFAULT 'AVAILABLE',
  localizacao JSONB NOT NULL, 
  inicio_janela_coleta TIMESTAMPTZ NOT NULL, 
  fim_janela_coleta TIMESTAMPTZ NOT NULL, 
  criado_em TIMESTAMPTZ DEFAULT NOW(), 
  atualizado_em TIMESTAMPTZ DEFAULT NOW(), 
  ong_reivindicadora_id UUID REFERENCES public.perfis(id) 
);

-- Índice GIST para busca geoespacial eficiente usando PostGIS.
CREATE INDEX idx_doacoes_geo ON public.doacoes USING GIST (ST_SetSRID(ST_MakePoint((localizacao->>'longitude')::float, (localizacao->>'latitude')::float), 4326)::geography);

ALTER TABLE public.doacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doacoes: Visualização de doações disponíveis" ON public.doacoes
  FOR SELECT USING (status = 'AVAILABLE');

CREATE POLICY "Doacoes: Doador gerencia suas doações" ON public.doacoes
  FOR ALL USING (auth.uid() = doador_id);

CREATE POLICY "Doacoes: ONGs verificadas podem reivindicar" ON public.doacoes
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM public.perfis
      WHERE id = auth.uid() AND funcao = 'NGO' AND status = 'VERIFIED'
    )
  );

-- 5. TABELA DE REGISTROS DE AUDITORIA (Audit_Logs)
-- Registra todas as ações importantes para rastreabilidade.
CREATE TABLE public.registros_auditoria (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  usuario_id UUID REFERENCES public.perfis(id),
  acao TEXT NOT NULL,
  id_alvo UUID,
  detalhes JSONB,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.registros_auditoria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Registros: Admin pode visualizar" ON public.registros_auditoria
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.perfis WHERE id = auth.uid() AND funcao = 'ADMIN')
  );

-- 6. AUTOMAÇÃO DE PERFIL (TRIGGER)
-- Cria um perfil na tabela 'perfis' automaticamente após o registro de um novo usuário em auth.users.
CREATE OR REPLACE FUNCTION public.gerar_perfil_automatico()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfis (id, email, nome, telefone, funcao, cnpj, status)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nome_completo', ''),
    COALESCE(NEW.raw_user_meta_data->>'telefone', ''),
    COALESCE(NEW.raw_user_meta_data->>'tipo_usuario', 'DONOR')::funcao_usuario,
    COALESCE(NEW.raw_user_meta_data->>'cnpj', ''),
    'PENDING_VERIFICATION'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_novo_usuario_auth
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.gerar_perfil_automatico();

-- 7. BUSCA POR RAIO (FUNÇÃO RPC)
-- Permite buscar doações próximas a uma localização específica dentro de um raio.
CREATE OR REPLACE FUNCTION public.buscar_doacoes_proximas(
  lat_usuario FLOAT,
  lng_usuario FLOAT,
  raio_km FLOAT DEFAULT 10.0
)
RETURNS TABLE (
  id UUID,
  tipo_alimento tipo_doacao,
  quantidade DECIMAL,
  unidade unidade_medida,
  data_validade TIMESTAMPTZ,
  endereco JSONB,
  distancia_km FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.tipo_alimento,
    d.quantidade,
    d.unidade,
    d.data_validade,
    d.localizacao AS endereco,
    ST_Distance(
      ST_SetSRID(ST_MakePoint((d.localizacao->>'longitude')::float, (d.localizacao->>'latitude')::float), 4326)::geography,
      ST_SetSRID(ST_MakePoint(lng_usuario, lat_usuario), 4326)::geography
    ) / 1000 AS distancia_km
  FROM public.doacoes d
  WHERE d.status = 'AVAILABLE'
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint((d.localizacao->>'longitude')::float, (d.localizacao->>'latitude')::float), 4326)::geography,
      ST_SetSRID(ST_MakePoint(lng_usuario, lat_usuario), 4326)::geography,
      raio_km * 1000
    )
  ORDER BY distancia_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. CONFIGURAÇÃO DO STORAGE PARA DOCUMENTOS DE VERIFICAÇÃO
-- Cria o bucket e define políticas de acesso para documentos de verificação.
INSERT INTO storage.buckets (id, name, public) VALUES ('documentos-verificacao', 'documentos-verificacao', false);

CREATE POLICY "Documentos Storage: Admin pode visualizar" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'documentos-verificacao' AND
    EXISTS (SELECT 1 FROM public.perfis WHERE id = auth.uid() AND funcao = 'ADMIN')
  );

CREATE POLICY "Documentos Storage: Upload autenticado" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'documentos-verificacao');

CREATE POLICY "Documentos Storage: Dono pode deletar" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'documentos-verificacao' AND owner = auth.uid());

CREATE POLICY "Documentos Storage: Dono pode atualizar" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'documentos-verificacao' AND owner = auth.uid());