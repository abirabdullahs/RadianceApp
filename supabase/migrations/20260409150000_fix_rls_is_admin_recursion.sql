-- Fix 42P17: infinite recursion on public.users.
-- 1) is_admin / is_student: SET row_security = off for the whole function (not SET LOCAL in body).
-- 2) Split users SELECT/UPDATE so own-row paths do not depend on OR is_admin().

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
SET row_security = off
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_student()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
SET row_security = off
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'student'
  );
$$;

DROP POLICY IF EXISTS "users_select_own_or_admin" ON public.users;
DROP POLICY IF EXISTS "users_update_own_or_admin" ON public.users;
DROP POLICY IF EXISTS "users_select_own" ON public.users;
DROP POLICY IF EXISTS "users_select_as_admin" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;
DROP POLICY IF EXISTS "users_update_as_admin" ON public.users;

CREATE POLICY "users_select_own" ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "users_select_as_admin" ON public.users FOR SELECT
  USING (public.is_admin());

CREATE POLICY "users_update_own" ON public.users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_as_admin" ON public.users FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
