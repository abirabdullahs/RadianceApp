-- 1) Allow reading peer profiles for community + doubt chat (names/avatars in UI).
--    Without this, students only pass users_select_own and _ensureSendersLoaded gets no rows.

CREATE OR REPLACE FUNCTION public.user_visible_for_community_chat(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_members cm1
    INNER JOIN public.community_members cm2
      ON cm2.group_id = cm1.group_id AND cm2.user_id = p_user_id
    WHERE cm1.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.community_messages m
    INNER JOIN public.community_members cm ON cm.group_id = m.group_id AND cm.user_id = auth.uid()
    WHERE m.sender_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.user_visible_for_doubt_chat(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.doubt_threads dt
    WHERE dt.student_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM public.doubt_messages dm
        WHERE dm.doubt_id = dt.id AND dm.sender_id = p_user_id
      )
  )
  OR EXISTS (
    SELECT 1 FROM public.doubt_threads dt
    WHERE dt.student_id = p_user_id
      AND public.is_staff_doubt()
  );
$$;

CREATE POLICY "users_select_chat_peers" ON public.users FOR SELECT
  USING (
    public.user_visible_for_community_chat(id)
    OR public.user_visible_for_doubt_chat(id)
  );

-- 2) Storage: public bucket "community" for chat + doubt attachments (was missing in migrations).

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('community', 'community', true, 52428800)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- Allow anyone to read objects in this public bucket (URLs work in app).
DROP POLICY IF EXISTS "community_public_read" ON storage.objects;
CREATE POLICY "community_public_read"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'community');

-- Authenticated users can upload (community paths + doubts/... paths).
DROP POLICY IF EXISTS "community_authenticated_insert" ON storage.objects;
CREATE POLICY "community_authenticated_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'community');

-- Optional: allow users to replace own uploads (same path).
DROP POLICY IF EXISTS "community_authenticated_update" ON storage.objects;
CREATE POLICY "community_authenticated_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'community')
  WITH CHECK (bucket_id = 'community');