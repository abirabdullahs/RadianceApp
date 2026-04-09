-- Pre-OTP signup interest (name + phone). Anonymous users can register interest;
-- admins can read. OTP completion is optional for saving the row.
--
-- [public.is_admin] is defined in 20260409000001_rls_policies.sql. If you run only
-- this file in the SQL editor, the helper is created here so the admin policy works.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin',
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin',
    false
  );
$$;

CREATE TABLE IF NOT EXISTS public.signup_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(15) NOT NULL,
  full_name_bn TEXT NOT NULL,
  otp_completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT signup_leads_phone_unique UNIQUE (phone)
);

CREATE INDEX IF NOT EXISTS signup_leads_created_at_idx ON public.signup_leads (created_at DESC);

ALTER TABLE public.signup_leads ENABLE ROW LEVEL SECURITY;

-- Idempotent re-runs (SQL editor / partial apply)
DROP POLICY IF EXISTS "signup_leads_insert_anon" ON public.signup_leads;
DROP POLICY IF EXISTS "signup_leads_insert_auth" ON public.signup_leads;
DROP POLICY IF EXISTS "signup_leads_select_admin" ON public.signup_leads;

CREATE POLICY "signup_leads_insert_anon"
  ON public.signup_leads FOR INSERT TO anon
  WITH CHECK (true);

CREATE POLICY "signup_leads_insert_auth"
  ON public.signup_leads FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "signup_leads_select_admin"
  ON public.signup_leads FOR SELECT TO authenticated
  USING (public.is_admin());

-- Upsert without exposing open UPDATE to anon (SECURITY DEFINER).
CREATE OR REPLACE FUNCTION public.upsert_signup_lead(p_phone text, p_name text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.signup_leads (phone, full_name_bn)
  VALUES (trim(p_phone), trim(p_name))
  ON CONFLICT (phone) DO UPDATE
    SET full_name_bn = EXCLUDED.full_name_bn,
        updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_signup_lead(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_signup_lead(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.upsert_signup_lead(text, text) TO authenticated;

-- After OTP: mark lead verified (phone must match [users.phone] for caller).
CREATE OR REPLACE FUNCTION public.mark_signup_lead_otp_completed(p_phone text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.phone = trim(p_phone)
  ) THEN
    RETURN;
  END IF;
  UPDATE public.signup_leads
  SET otp_completed = true, updated_at = now()
  WHERE phone = trim(p_phone);
END;
$$;

REVOKE ALL ON FUNCTION public.mark_signup_lead_otp_completed(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_signup_lead_otp_completed(text) TO authenticated;
