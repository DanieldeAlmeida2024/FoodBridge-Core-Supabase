CREATE OR REPLACE FUNCTION public.get_nearby_donations(
  user_lat FLOAT,
  user_lng FLOAT,
  radius_km FLOAT DEFAULT 10.0
)
RETURNS TABLE (
  id UUID,
  donor_id UUID,
  food_type TEXT,
  description TEXT,
  quantity TEXT,
  expiration_date TIMESTAMPTZ,
  address TEXT,
  status TEXT,
  distance_km FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.donor_id,
    d.food_type,
    d.description,
    d.quantity,
    d.expiration_date,
    d.address,
    d.status,
    ST_Distance(
      d.location_coords,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) / 1000 AS distance_km
  FROM public.donations d
  WHERE d.status = 'AVAILABLE'
    AND ST_DWithin(
      d.location_coords,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. TRIGGER PARA ATUALIZAR UPDATED_AT
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_donations_updated_at
  BEFORE UPDATE ON public.donations
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();