-- Fix 42P17 without relying on SET row_security (often ignored / denied on Supabase).
-- is_admin() / is_student() read ONLY auth.jwt() — never query public.users (no recursion).
-- Sync public.users.role → auth.users.raw_app_meta_data.role so JWT contains role after login.

-- 1) Keep auth.users metadata in sync with public.users.role
CREATE OR REPLACE FUNCTION public.sync_user_role_to_auth_metadata()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE auth.users
  SET raw_app_meta_data =
    COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', NEW.role::text)
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_sync_role_to_auth ON public.users;

CREATE TRIGGER trg_users_sync_role_to_auth
  AFTER INSERT OR UPDATE OF role ON public.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.sync_user_role_to_auth_metadata();

-- 2) One-time backfill (existing rows)
UPDATE auth.users au
SET raw_app_meta_data =
  COALESCE(au.raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', u.role::text)
FROM public.users u
WHERE u.id = au.id;

-- 3) Role helpers for non-users tables (invoker JWT; no SECURITY DEFINER).
-- Policies ON public.users must use inline JWT — see 20260409180000_users_policies_inline_jwt.sql
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

CREATE OR REPLACE FUNCTION public.is_student()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'student',
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'student',
    false
  );
$$;
