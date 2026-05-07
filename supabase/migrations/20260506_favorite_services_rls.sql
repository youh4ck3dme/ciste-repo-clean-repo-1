-- favorite_services RLS hardening
-- 1) remove any policies that relied on client_id = auth.uid()
DROP POLICY IF EXISTS "favorite_services_select_own" ON public.favorite_services;
DROP POLICY IF EXISTS "favorite_services_insert_own" ON public.favorite_services;
DROP POLICY IF EXISTS "favorite_services_delete_own" ON public.favorite_services;
DROP POLICY IF EXISTS "Users can view own favorites" ON public.favorite_services;
DROP POLICY IF EXISTS "Users can insert own favorites" ON public.favorite_services;
DROP POLICY IF EXISTS "Users can delete own favorites" ON public.favorite_services;

-- 2) enforce ownership exclusively via client_profiles join
CREATE POLICY "favorite_services_select_via_client_profiles"
ON public.favorite_services
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.client_profiles
    WHERE client_profiles.id = favorite_services.client_id
      AND client_profiles.user_id = auth.uid()
  )
);

CREATE POLICY "favorite_services_insert_via_client_profiles"
ON public.favorite_services
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.client_profiles
    WHERE client_profiles.id = favorite_services.client_id
      AND client_profiles.user_id = auth.uid()
  )
);

CREATE POLICY "favorite_services_delete_via_client_profiles"
ON public.favorite_services
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM public.client_profiles
    WHERE client_profiles.id = favorite_services.client_id
      AND client_profiles.user_id = auth.uid()
  )
);

-- 4) uniqueness guard so one client cannot favorite the same service twice
CREATE UNIQUE INDEX IF NOT EXISTS favorite_services_client_service_uidx
ON public.favorite_services (client_id, service_id);
