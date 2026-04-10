-- Attendance settings (singleton)

CREATE TABLE IF NOT EXISTS public.attendance_settings (
  singleton_key integer PRIMARY KEY DEFAULT 1 CHECK (singleton_key = 1),
  warning_threshold_pct integer NOT NULL DEFAULT 75 CHECK (warning_threshold_pct BETWEEN 1 AND 100),
  auto_sms_enabled boolean NOT NULL DEFAULT false,
  sort_order text NOT NULL DEFAULT 'roll'
    CHECK (sort_order IN ('roll', 'name_en', 'name_bn', 'join_date')),
  auto_advance_delay_ms integer NOT NULL DEFAULT 300 CHECK (auto_advance_delay_ms BETWEEN 0 AND 1000),
  default_status text NOT NULL DEFAULT 'absent'
    CHECK (default_status IN ('absent', 'present')),
  updated_by uuid REFERENCES public.users(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.attendance_settings (singleton_key)
VALUES (1)
ON CONFLICT (singleton_key) DO NOTHING;

ALTER TABLE public.attendance_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_settings_select" ON public.attendance_settings;
CREATE POLICY "attendance_settings_select"
ON public.attendance_settings
FOR SELECT
USING (public.is_admin());

DROP POLICY IF EXISTS "attendance_settings_write" ON public.attendance_settings;
CREATE POLICY "attendance_settings_write"
ON public.attendance_settings
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());
