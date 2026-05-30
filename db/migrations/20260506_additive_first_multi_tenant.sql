BEGIN;

-- 1) Core tenant tables
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','disabled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tenant_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('owner','admin','staff','viewer')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.tenant_branding (
  tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
  brand_name text,
  logo_url text,
  primary_color text,
  secondary_color text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tenant_domains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  domain text NOT NULL UNIQUE,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, domain)
);

CREATE TABLE IF NOT EXISTS public.tenant_feature_flags (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  flag_key text NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, flag_key)
);

CREATE TABLE IF NOT EXISTS public.tenant_ai_settings (
  tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
  provider text,
  model text,
  temperature numeric(4,3),
  max_tokens integer,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2) Add tenant_id to tenant-scoped tables
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.blocked_dates ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.blocked_slots ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.time_slots_config ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.client_profiles ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.booking_events ADD COLUMN IF NOT EXISTS tenant_id uuid;
ALTER TABLE public.booking_reminders ADD COLUMN IF NOT EXISTS tenant_id uuid;

-- 3) Backfill existing data with default tenant
WITH default_tenant AS (
  INSERT INTO public.tenants (slug, name)
  VALUES ('default', 'Default tenant')
  ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id
), picked_tenant AS (
  SELECT id FROM default_tenant
  UNION ALL
  SELECT id FROM public.tenants WHERE slug = 'default' LIMIT 1
)
UPDATE public.bookings b SET tenant_id = p.id FROM picked_tenant p WHERE b.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.services t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.employees t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.blocked_dates t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.blocked_slots t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.time_slots_config t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.client_profiles t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.booking_events t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;
WITH picked_tenant AS (SELECT id FROM public.tenants WHERE slug='default' LIMIT 1)
UPDATE public.booking_reminders t SET tenant_id = p.id FROM picked_tenant p WHERE t.tenant_id IS NULL;

-- Make tenant_id mandatory + FKs
ALTER TABLE public.bookings ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.services ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.employees ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.blocked_dates ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.blocked_slots ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.time_slots_config ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.client_profiles ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.booking_events ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE public.booking_reminders ALTER COLUMN tenant_id SET NOT NULL;

ALTER TABLE public.bookings ADD CONSTRAINT bookings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.services ADD CONSTRAINT services_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.employees ADD CONSTRAINT employees_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.blocked_dates ADD CONSTRAINT blocked_dates_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.blocked_slots ADD CONSTRAINT blocked_slots_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.time_slots_config ADD CONSTRAINT time_slots_config_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.client_profiles ADD CONSTRAINT client_profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.booking_events ADD CONSTRAINT booking_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;
ALTER TABLE public.booking_reminders ADD CONSTRAINT booking_reminders_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;

-- 4) tenant-aware resolver + RPC helpers
CREATE OR REPLACE FUNCTION public.resolve_tenant_id(p_host text, p_slug text DEFAULT NULL)
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT t.id
  FROM public.tenants t
  LEFT JOIN public.tenant_domains d ON d.tenant_id = t.id
  WHERE (p_slug IS NOT NULL AND t.slug = p_slug)
     OR (p_host IS NOT NULL AND d.domain = p_host)
  ORDER BY d.is_primary DESC NULLS LAST
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::uuid
$$;

-- wrappers expecting tenant filter in internals of existing RPCs
CREATE OR REPLACE FUNCTION public.create_secure_booking_tenant(
  p_tenant_id uuid,
  p_payload jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id required';
  END IF;
  RETURN public.create_secure_booking(p_tenant_id, p_payload);
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_secure_booking_tenant(
  p_tenant_id uuid,
  p_booking_id uuid,
  p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id required';
  END IF;
  RETURN public.cancel_secure_booking(p_tenant_id, p_booking_id, p_reason);
END;
$$;

-- 5) RLS tenant boundary policies
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_branding ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_ai_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_slots_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_reminders ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_tenant_admin(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.tenant_users tu
    WHERE tu.tenant_id = p_tenant_id
      AND tu.user_id = auth.uid()
      AND tu.role IN ('owner','admin')
  )
$$;

DO $$
DECLARE
  t text;
  tenant_tables text[] := ARRAY[
    'bookings','services','employees','blocked_dates','blocked_slots','time_slots_config','client_profiles','booking_events','booking_reminders'
  ];
BEGIN
  FOREACH t IN ARRAY tenant_tables
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_select ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_write ON public.%I', t, t);
    EXECUTE format('CREATE POLICY %I_tenant_select ON public.%I FOR SELECT USING (tenant_id IN (SELECT tenant_id FROM public.tenant_users WHERE user_id = auth.uid()))', t, t);
    EXECUTE format('CREATE POLICY %I_tenant_write ON public.%I FOR ALL USING (tenant_id IN (SELECT tenant_id FROM public.tenant_users WHERE user_id = auth.uid())) WITH CHECK (tenant_id IN (SELECT tenant_id FROM public.tenant_users WHERE user_id = auth.uid()))', t, t);
  END LOOP;
END $$;

CREATE POLICY tenant_users_select ON public.tenant_users
FOR SELECT USING (user_id = auth.uid() OR public.is_tenant_admin(tenant_id));
CREATE POLICY tenant_users_write ON public.tenant_users
FOR ALL USING (public.is_tenant_admin(tenant_id))
WITH CHECK (public.is_tenant_admin(tenant_id));

-- 6) tenant-prefixed indexes
CREATE INDEX IF NOT EXISTS idx_bookings_tenant_date_time ON public.bookings(tenant_id, date, time_slot_time);
CREATE INDEX IF NOT EXISTS idx_services_tenant ON public.services(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_tenant ON public.employees(tenant_id);
CREATE INDEX IF NOT EXISTS idx_blocked_dates_tenant_date ON public.blocked_dates(tenant_id, date);
CREATE INDEX IF NOT EXISTS idx_blocked_slots_tenant_date_time ON public.blocked_slots(tenant_id, date, time_slot_time);
CREATE INDEX IF NOT EXISTS idx_time_slots_config_tenant_weekday ON public.time_slots_config(tenant_id, weekday);
CREATE INDEX IF NOT EXISTS idx_client_profiles_tenant_email ON public.client_profiles(tenant_id, email);
CREATE INDEX IF NOT EXISTS idx_booking_events_tenant_booking ON public.booking_events(tenant_id, booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_reminders_tenant_booking ON public.booking_reminders(tenant_id, booking_id);

COMMIT;
