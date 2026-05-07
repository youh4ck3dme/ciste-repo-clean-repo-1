-- Additive-safe migration for bookings.time_slot -> bookings.time_slot_time
-- Date: 2026-05-06

BEGIN;

-- 1) Add the new column (additive, nullable for rollout safety)
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS time_slot_time time;

-- 2) Legacy format validation guard for rows that still require backfill.
--    This check is intentionally NOT VALID first, then validated,
--    so existing bad data can be discovered in a controlled way.
--    Accepts HH:MM and optional :SS.
ALTER TABLE public.bookings
  ADD CONSTRAINT IF NOT EXISTS bookings_time_slot_legacy_format_chk
  CHECK (
    time_slot IS NULL
    OR time_slot ~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$'
  ) NOT VALID;

COMMIT;

-- 2a) Pre-validation diagnostics (run and inspect before VALIDATE/BACKFILL)
-- Rows with invalid legacy format:
--   SELECT id, time_slot
--   FROM public.bookings
--   WHERE time_slot IS NOT NULL
--     AND NOT (time_slot ~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$');
--
-- Rows missing the new value but having legacy value:
--   SELECT count(*)
--   FROM public.bookings
--   WHERE time_slot_time IS NULL
--     AND time_slot IS NOT NULL;

-- 2b) Validate constraint after cleaning invalid legacy rows.
ALTER TABLE public.bookings
  VALIDATE CONSTRAINT bookings_time_slot_legacy_format_chk;

-- 2c) Backfill (idempotent, only missing target rows)
UPDATE public.bookings
SET time_slot_time = time_slot::time
WHERE time_slot_time IS NULL
  AND time_slot IS NOT NULL;

-- 5) Add rollout index for new access path
CREATE INDEX IF NOT EXISTS bookings_date_time_slot_time_employee_status_idx
  ON public.bookings (date, time_slot_time, employee_id, status);

-- 4) RPC functions migrated to prefer time_slot_time while preserving compatibility.
-- NOTE: Replace argument/default details with your exact production signatures if they differ.

CREATE OR REPLACE FUNCTION public.create_secure_booking(
  p_customer_id uuid,
  p_employee_id uuid,
  p_service_id uuid,
  p_date date,
  p_time_slot text,
  p_notes text DEFAULT NULL
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_time_slot_time time;
  v_row public.bookings;
BEGIN
  v_time_slot_time := p_time_slot::time;

  INSERT INTO public.bookings (
    customer_id,
    employee_id,
    service_id,
    date,
    time_slot,
    time_slot_time,
    notes,
    status
  )
  VALUES (
    p_customer_id,
    p_employee_id,
    p_service_id,
    p_date,
    p_time_slot,
    v_time_slot_time,
    p_notes,
    'confirmed'
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_secure_booking(
  p_booking_id uuid,
  p_customer_id uuid
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row public.bookings;
BEGIN
  UPDATE public.bookings b
  SET
    status = 'cancelled',
    updated_at = now()
  WHERE b.id = p_booking_id
    AND b.customer_id = p_customer_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_booking_slot_counts(
  p_employee_id uuid,
  p_date date
)
RETURNS TABLE(slot_time time, bookings_count bigint)
LANGUAGE sql
STABLE
AS $$
  SELECT
    COALESCE(b.time_slot_time, b.time_slot::time) AS slot_time,
    count(*)::bigint AS bookings_count
  FROM public.bookings b
  WHERE b.employee_id = p_employee_id
    AND b.date = p_date
    AND b.status IN ('pending', 'confirmed')
  GROUP BY COALESCE(b.time_slot_time, b.time_slot::time)
  ORDER BY COALESCE(b.time_slot_time, b.time_slot::time);
$$;

CREATE OR REPLACE FUNCTION public.get_opening_hours_conflicts(
  p_employee_id uuid,
  p_date date,
  p_slot_start time,
  p_slot_end time
)
RETURNS TABLE(conflict_booking_id uuid, conflict_slot_time time)
LANGUAGE sql
STABLE
AS $$
  SELECT
    b.id AS conflict_booking_id,
    COALESCE(b.time_slot_time, b.time_slot::time) AS conflict_slot_time
  FROM public.bookings b
  WHERE b.employee_id = p_employee_id
    AND b.date = p_date
    AND b.status IN ('pending', 'confirmed')
    AND COALESCE(b.time_slot_time, b.time_slot::time) >= p_slot_start
    AND COALESCE(b.time_slot_time, b.time_slot::time) < p_slot_end;
$$;

-- 6) Rollout notes:
--    a) FE/BE write both fields during transition:
--       - time_slot      (legacy text payload)
--       - time_slot_time (canonical time)
--    b) Once FE/BE are stable and all consumers updated, switch read paths to time_slot_time only.
--    c) Later migration: drop dependency on time_slot, remove legacy constraint/index usage, then drop column.
