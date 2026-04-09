-- Teacher role + doubt solve threads/messages (chat per doubt).

-- 1) Allow teacher in users.role
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin', 'student', 'teacher'));

-- 2) JWT helpers (inline only; no users table reads)
CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'teacher',
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'teacher',
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.is_staff_doubt()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT public.is_admin() OR public.is_teacher();
$$;

-- 3) Tables
CREATE TABLE public.doubt_threads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  problem_description TEXT NOT NULL,
  problem_image_url TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'solved')),
  solved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_doubt_threads_student ON public.doubt_threads(student_id);
CREATE INDEX idx_doubt_threads_created ON public.doubt_threads(created_at DESC);

CREATE TABLE public.doubt_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doubt_id UUID NOT NULL REFERENCES public.doubt_threads(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  message_type VARCHAR(20) NOT NULL DEFAULT 'text'
    CHECK (message_type IN ('text', 'image', 'voice', 'file')),
  body TEXT,
  file_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_doubt_messages_doubt ON public.doubt_messages(doubt_id, created_at);

-- 4) RLS
ALTER TABLE public.doubt_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doubt_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "doubt_threads_select" ON public.doubt_threads FOR SELECT
  USING (
    student_id = auth.uid()
    OR public.is_staff_doubt()
  );

CREATE POLICY "doubt_threads_insert_student" ON public.doubt_threads FOR INSERT
  WITH CHECK (
    student_id = auth.uid()
    AND (
      (auth.jwt() -> 'app_metadata' ->> 'role') = 'student'
      OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'student'
    )
  );

CREATE POLICY "doubt_threads_update" ON public.doubt_threads FOR UPDATE
  USING (
    student_id = auth.uid()
    OR public.is_staff_doubt()
  )
  WITH CHECK (
    student_id = auth.uid()
    OR public.is_staff_doubt()
  );

CREATE POLICY "doubt_messages_select" ON public.doubt_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.doubt_threads t
      WHERE t.id = doubt_messages.doubt_id
        AND (
          t.student_id = auth.uid()
          OR public.is_staff_doubt()
        )
    )
  );

CREATE POLICY "doubt_messages_insert" ON public.doubt_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.doubt_threads t
      WHERE t.id = doubt_messages.doubt_id
        AND (
          t.student_id = auth.uid()
          OR public.is_staff_doubt()
        )
    )
  );

-- 5) Purge chat messages (SECURITY DEFINER; app asks user before calling)
CREATE OR REPLACE FUNCTION public.purge_doubt_messages(p_doubt_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sid uuid;
BEGIN
  SELECT student_id INTO sid FROM public.doubt_threads WHERE id = p_doubt_id;
  IF sid IS NULL THEN
    RAISE EXCEPTION 'doubt not found';
  END IF;
  IF NOT (
    auth.uid() = sid
    OR public.is_admin()
    OR public.is_teacher()
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  DELETE FROM public.doubt_messages WHERE doubt_id = p_doubt_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.purge_doubt_messages(uuid) TO authenticated;
