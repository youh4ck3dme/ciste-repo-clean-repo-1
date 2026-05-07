-- psql-style integration checks for favorite_services RLS contract
-- expects test fixtures with two auth users and matching client_profiles

-- 0) unique constraint/index exists
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'favorite_services'
  AND indexname = 'favorite_services_client_service_uidx';

-- 1) own insert/select/delete works
-- set local role and jwt claims in your test harness before each block
-- Example uses pseudo helper: select test_auth_as('<uuid>');

-- user_a inserts into own client profile
INSERT INTO public.favorite_services (client_id, service_id)
SELECT cp.id, '00000000-0000-0000-0000-000000000101'::uuid
FROM public.client_profiles cp
WHERE cp.user_id = '00000000-0000-0000-0000-0000000000a1'::uuid;

-- user_a can read only own
SELECT fs.*
FROM public.favorite_services fs
JOIN public.client_profiles cp ON cp.id = fs.client_id
WHERE cp.user_id = '00000000-0000-0000-0000-0000000000a1'::uuid;

-- user_a deletes own
DELETE FROM public.favorite_services fs
USING public.client_profiles cp
WHERE cp.id = fs.client_id
  AND cp.user_id = '00000000-0000-0000-0000-0000000000a1'::uuid
  AND fs.service_id = '00000000-0000-0000-0000-000000000101'::uuid;

-- 2) cross-user access must be denied by RLS
-- user_b trying to insert favorite for user_a client_id must fail
-- user_b trying to select user_a favorites must return no rows
-- user_b trying to delete user_a favorites must affect 0 rows
