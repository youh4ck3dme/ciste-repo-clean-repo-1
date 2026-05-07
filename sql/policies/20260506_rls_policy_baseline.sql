-- RLS policy baseline (deduplicated + unified naming)
-- Naming convention: <table>_<role>_<action>

begin;

-- 1) Export helper (run before applying changes):
-- select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- from pg_policies
-- where schemaname = 'public'
--   and tablename in (
--     'bookings','push_subscriptions','blocked_dates','time_slots_config','favorite_services','client_profiles'
--   )
-- order by tablename, cmd, policyname;

-- 2) bookings
alter table if exists public.bookings enable row level security;
drop policy if exists bookings_anon_select on public.bookings;
drop policy if exists bookings_anon_insert on public.bookings;
drop policy if exists bookings_anon_update on public.bookings;
drop policy if exists bookings_anon_delete on public.bookings;
drop policy if exists bookings_authenticated_select on public.bookings;
drop policy if exists bookings_authenticated_insert on public.bookings;
drop policy if exists bookings_authenticated_update on public.bookings;
drop policy if exists bookings_authenticated_delete on public.bookings;
drop policy if exists bookings_service_role_select on public.bookings;
drop policy if exists bookings_service_role_insert on public.bookings;
drop policy if exists bookings_service_role_update on public.bookings;
drop policy if exists bookings_service_role_delete on public.bookings;
drop policy if exists bookings_admin_select on public.bookings;
drop policy if exists bookings_admin_insert on public.bookings;
drop policy if exists bookings_admin_update on public.bookings;
drop policy if exists bookings_admin_delete on public.bookings;

create policy bookings_authenticated_select on public.bookings for select to authenticated using (user_id = auth.uid());
create policy bookings_authenticated_insert on public.bookings for insert to authenticated with check (user_id = auth.uid());
create policy bookings_authenticated_update on public.bookings for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy bookings_service_role_select on public.bookings for select to service_role using (true);
create policy bookings_service_role_insert on public.bookings for insert to service_role with check (true);
create policy bookings_service_role_update on public.bookings for update to service_role using (true) with check (true);
create policy bookings_service_role_delete on public.bookings for delete to service_role using (true);
create policy bookings_admin_select on public.bookings for select to admin using (true);
create policy bookings_admin_insert on public.bookings for insert to admin with check (true);
create policy bookings_admin_update on public.bookings for update to admin using (true) with check (true);
create policy bookings_admin_delete on public.bookings for delete to admin using (true);

-- 3) push_subscriptions
alter table if exists public.push_subscriptions enable row level security;
drop policy if exists push_subscriptions_authenticated_select on public.push_subscriptions;
drop policy if exists push_subscriptions_authenticated_insert on public.push_subscriptions;
drop policy if exists push_subscriptions_authenticated_update on public.push_subscriptions;
drop policy if exists push_subscriptions_authenticated_delete on public.push_subscriptions;
drop policy if exists push_subscriptions_service_role_select on public.push_subscriptions;
drop policy if exists push_subscriptions_service_role_insert on public.push_subscriptions;
drop policy if exists push_subscriptions_service_role_update on public.push_subscriptions;
drop policy if exists push_subscriptions_service_role_delete on public.push_subscriptions;
drop policy if exists push_subscriptions_admin_select on public.push_subscriptions;
drop policy if exists push_subscriptions_admin_insert on public.push_subscriptions;
drop policy if exists push_subscriptions_admin_update on public.push_subscriptions;
drop policy if exists push_subscriptions_admin_delete on public.push_subscriptions;

create policy push_subscriptions_authenticated_select on public.push_subscriptions for select to authenticated using (user_id = auth.uid());
create policy push_subscriptions_authenticated_insert on public.push_subscriptions for insert to authenticated with check (user_id = auth.uid());
create policy push_subscriptions_authenticated_update on public.push_subscriptions for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy push_subscriptions_authenticated_delete on public.push_subscriptions for delete to authenticated using (user_id = auth.uid());
create policy push_subscriptions_service_role_select on public.push_subscriptions for select to service_role using (true);
create policy push_subscriptions_service_role_insert on public.push_subscriptions for insert to service_role with check (true);
create policy push_subscriptions_service_role_update on public.push_subscriptions for update to service_role using (true) with check (true);
create policy push_subscriptions_service_role_delete on public.push_subscriptions for delete to service_role using (true);
create policy push_subscriptions_admin_select on public.push_subscriptions for select to admin using (true);
create policy push_subscriptions_admin_insert on public.push_subscriptions for insert to admin with check (true);
create policy push_subscriptions_admin_update on public.push_subscriptions for update to admin using (true) with check (true);
create policy push_subscriptions_admin_delete on public.push_subscriptions for delete to admin using (true);

-- 4) blocked_dates
alter table if exists public.blocked_dates enable row level security;
create policy blocked_dates_anon_select on public.blocked_dates for select to anon using (true);
create policy blocked_dates_authenticated_select on public.blocked_dates for select to authenticated using (true);
create policy blocked_dates_service_role_select on public.blocked_dates for select to service_role using (true);
create policy blocked_dates_service_role_insert on public.blocked_dates for insert to service_role with check (true);
create policy blocked_dates_service_role_update on public.blocked_dates for update to service_role using (true) with check (true);
create policy blocked_dates_service_role_delete on public.blocked_dates for delete to service_role using (true);
create policy blocked_dates_admin_select on public.blocked_dates for select to admin using (true);
create policy blocked_dates_admin_insert on public.blocked_dates for insert to admin with check (true);
create policy blocked_dates_admin_update on public.blocked_dates for update to admin using (true) with check (true);
create policy blocked_dates_admin_delete on public.blocked_dates for delete to admin using (true);

-- 5) time_slots_config
alter table if exists public.time_slots_config enable row level security;
create policy time_slots_config_anon_select on public.time_slots_config for select to anon using (true);
create policy time_slots_config_authenticated_select on public.time_slots_config for select to authenticated using (true);
create policy time_slots_config_service_role_select on public.time_slots_config for select to service_role using (true);
create policy time_slots_config_service_role_insert on public.time_slots_config for insert to service_role with check (true);
create policy time_slots_config_service_role_update on public.time_slots_config for update to service_role using (true) with check (true);
create policy time_slots_config_service_role_delete on public.time_slots_config for delete to service_role using (true);
create policy time_slots_config_admin_select on public.time_slots_config for select to admin using (true);
create policy time_slots_config_admin_insert on public.time_slots_config for insert to admin with check (true);
create policy time_slots_config_admin_update on public.time_slots_config for update to admin using (true) with check (true);
create policy time_slots_config_admin_delete on public.time_slots_config for delete to admin using (true);

-- 6) favorite_services
alter table if exists public.favorite_services enable row level security;
create policy favorite_services_authenticated_select on public.favorite_services for select to authenticated using (user_id = auth.uid());
create policy favorite_services_authenticated_insert on public.favorite_services for insert to authenticated with check (user_id = auth.uid());
create policy favorite_services_authenticated_update on public.favorite_services for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy favorite_services_authenticated_delete on public.favorite_services for delete to authenticated using (user_id = auth.uid());
create policy favorite_services_service_role_select on public.favorite_services for select to service_role using (true);
create policy favorite_services_service_role_insert on public.favorite_services for insert to service_role with check (true);
create policy favorite_services_service_role_update on public.favorite_services for update to service_role using (true) with check (true);
create policy favorite_services_service_role_delete on public.favorite_services for delete to service_role using (true);
create policy favorite_services_admin_select on public.favorite_services for select to admin using (true);
create policy favorite_services_admin_insert on public.favorite_services for insert to admin with check (true);
create policy favorite_services_admin_update on public.favorite_services for update to admin using (true) with check (true);
create policy favorite_services_admin_delete on public.favorite_services for delete to admin using (true);

-- 7) client_profiles
alter table if exists public.client_profiles enable row level security;
create policy client_profiles_authenticated_select on public.client_profiles for select to authenticated using (id = auth.uid());
create policy client_profiles_authenticated_insert on public.client_profiles for insert to authenticated with check (id = auth.uid());
create policy client_profiles_authenticated_update on public.client_profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy client_profiles_service_role_select on public.client_profiles for select to service_role using (true);
create policy client_profiles_service_role_insert on public.client_profiles for insert to service_role with check (true);
create policy client_profiles_service_role_update on public.client_profiles for update to service_role using (true) with check (true);
create policy client_profiles_service_role_delete on public.client_profiles for delete to service_role using (true);
create policy client_profiles_admin_select on public.client_profiles for select to admin using (true);
create policy client_profiles_admin_insert on public.client_profiles for insert to admin with check (true);
create policy client_profiles_admin_update on public.client_profiles for update to admin using (true) with check (true);
create policy client_profiles_admin_delete on public.client_profiles for delete to admin using (true);

commit;
