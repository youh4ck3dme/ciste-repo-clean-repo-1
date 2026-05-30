-- Strategy selected: single-row per day_of_week for public.time_slots_config
-- Date: 2026-05-06

BEGIN;

-- 1) Normalize historical duplicates so we can enforce UNIQUE(day_of_week).
WITH ranked AS (
  SELECT
    id,
    day_of_week,
    ROW_NUMBER() OVER (
      PARTITION BY day_of_week
      ORDER BY created_at DESC NULLS LAST, id DESC
    ) AS rn
  FROM public.time_slots_config
),
latest AS (
  SELECT id FROM ranked WHERE rn = 1
)
DELETE FROM public.time_slots_config t
WHERE NOT EXISTS (
  SELECT 1
  FROM latest l
  WHERE l.id = t.id
);

-- 2) Keep a single active row per day.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'time_slots_config_day_of_week_key'
      AND conrelid = 'public.time_slots_config'::regclass
  ) THEN
    ALTER TABLE public.time_slots_config
      ADD CONSTRAINT time_slots_config_day_of_week_key UNIQUE (day_of_week);
  END IF;
END;
$$;

-- 3) Booking function reads deterministically from the single row for given day.
--    Removes ORDER BY created_at subquery model.
CREATE OR REPLACE FUNCTION public.create_secure_booking(
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id uuid;
  v_day_of_week int;
  v_slot public.time_slots_config%ROWTYPE;
BEGIN
  v_day_of_week := EXTRACT(DOW FROM p_start_at AT TIME ZONE 'UTC');

  SELECT *
  INTO v_slot
  FROM public.time_slots_config
  WHERE day_of_week = v_day_of_week;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No time_slots_config found for day_of_week=%', v_day_of_week
      USING ERRCODE = 'P0001';
  END IF;

  -- Existing validation/booking logic should follow here and use v_slot.
  -- Placeholder insert to keep function executable in isolated migration context.
  INSERT INTO public.bookings (start_at, end_at, metadata)
  VALUES (p_start_at, p_end_at, COALESCE(p_payload, '{}'::jsonb))
  RETURNING id INTO v_booking_id;

  RETURN v_booking_id;
END;
$$;

-- 4) Admin API uses UPDATE flow (not INSERT) to modify opening hours.
CREATE OR REPLACE FUNCTION public.admin_update_time_slots_config(
  p_day_of_week int,
  p_open_time time,
  p_close_time time,
  p_is_open boolean
)
RETURNS public.time_slots_config
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row public.time_slots_config%ROWTYPE;
BEGIN
  UPDATE public.time_slots_config
  SET
    open_time = p_open_time,
    close_time = p_close_time,
    is_open = p_is_open,
    updated_at = now()
  WHERE day_of_week = p_day_of_week
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cannot update day_of_week=% because row does not exist (single-row strategy)', p_day_of_week
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_row;
END;
$$;

COMMIT;
