-- Smoke test: verify deny-by-default posture for anon/authenticated where expected.
-- Run manually in psql or CI DB step after migration:
-- psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/tests/rls_deny_by_default_smoke.sql

begin;

set local role anon;
-- Expect: 0 rows or permission denied depending on grants/policies.
select count(*) as anon_bookings_visible from public.bookings;
select count(*) as anon_favorite_services_visible from public.favorite_services;
select count(*) as anon_client_profiles_visible from public.client_profiles;

set local role authenticated;
-- Expect: rows only for auth.uid() owner context.
select count(*) as auth_bookings_visible from public.bookings;
select count(*) as auth_favorite_services_visible from public.favorite_services;
select count(*) as auth_client_profiles_visible from public.client_profiles;

reset role;

-- Policy uniqueness check: one policy per table/role/action name.
select tablename, policyname, cmd, roles
from pg_policies
where schemaname='public'
  and tablename in (
    'bookings','push_subscriptions','blocked_dates','time_slots_config','favorite_services','client_profiles'
  )
order by tablename, policyname;

rollback;
