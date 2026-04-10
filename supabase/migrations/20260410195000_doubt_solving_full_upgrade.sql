-- Doubt solving full upgrade:
-- - Replace legacy `doubt_threads` runtime shape with `doubts`
-- - Add meeting workflow + student stats
-- - Add RPCs for solved/delete and meeting scheduling
-- - Keep admin + teacher staff access model

-- 1) Rename legacy table to planned name.
DO $$
BEGIN
  IF to_regclass('public.doubts') IS NULL AND to_regclass('public.doubt_threads') IS NOT NULL THEN
    ALTER TABLE public.doubt_threads RENAME TO doubts;
  END IF;
END $$;

-- 2) Upgrade doubts schema.
ALTER TABLE public.doubts
  RENAME COLUMN problem_description TO description;
ALTER TABLE public.doubts
  RENAME COLUMN problem_image_url TO image_url;

ALTER TABLE public.doubts
  ADD COLUMN IF NOT EXISTS course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS subject TEXT,
  ADD COLUMN IF NOT EXISTS chapter TEXT,
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS resolution_type VARCHAR(20),
  ADD COLUMN IF NOT EXISTS meeting_link TEXT,
  ADD COLUMN IF NOT EXISTS meeting_time TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS meeting_note TEXT,
  ADD COLUMN IF NOT EXISTS solved_by UUID REFERENCES public.users(id) ON DELETE SET NULL;

UPDATE public.doubts
SET title = LEFT(COALESCE(NULLIF(trim(description), ''), 'Untitled doubt'), 160)
WHERE title IS NULL OR trim(title) = '';

ALTER TABLE public.doubts
  ALTER COLUMN title SET NOT NULL;

ALTER TABLE public.doubts
  DROP CONSTRAINT IF EXISTS doubt_threads_status_check;
ALTER TABLE public.doubts
  DROP CONSTRAINT IF EXISTS doubts_status_check;
ALTER TABLE public.doubts
  ADD CONSTRAINT doubts_status_check
  CHECK (status IN ('open', 'in_progress', 'meeting_scheduled', 'solved'));

ALTER TABLE public.doubts
  DROP CONSTRAINT IF EXISTS doubts_resolution_type_check;
ALTER TABLE public.doubts
  ADD CONSTRAINT doubts_resolution_type_check
  CHECK (resolution_type IS NULL OR resolution_type IN ('chat', 'meeting'));

-- 3) Upgrade messages schema while preserving legacy columns.
ALTER TABLE public.doubt_messages
  ADD COLUMN IF NOT EXISTS content TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT;

UPDATE public.doubt_messages
SET
  content = COALESCE(content, body, ''),
  image_url = COALESCE(image_url, CASE WHEN message_type = 'image' THEN file_url ELSE NULL END)
WHERE content IS NULL OR image_url IS NULL;

ALTER TABLE public.doubt_messages
  ALTER COLUMN content SET NOT NULL;

-- Ensure FK points to doubts.id (rename from doubt_threads keeps target, this is safety).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'doubt_messages_doubt_id_fkey'
      AND conrelid = 'public.doubt_messages'::regclass
  ) THEN
    ALTER TABLE public.doubt_messages DROP CONSTRAINT doubt_messages_doubt_id_fkey;
  END IF;
END $$;

ALTER TABLE public.doubt_messages
  ADD CONSTRAINT doubt_messages_doubt_id_fkey
  FOREIGN KEY (doubt_id) REFERENCES public.doubts(id) ON DELETE CASCADE;

-- 4) Indexes for inbox + meeting lookups.
CREATE INDEX IF NOT EXISTS idx_doubts_status_created ON public.doubts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_doubts_student_status ON public.doubts(student_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_doubts_meeting_time ON public.doubts(meeting_time) WHERE meeting_time IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_doubt_messages_doubt_created ON public.doubt_messages(doubt_id, created_at);

-- 5) Student stats table.
CREATE TABLE IF NOT EXISTS public.student_doubt_stats (
  student_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  total_submitted INT NOT NULL DEFAULT 0 CHECK (total_submitted >= 0),
  total_solved INT NOT NULL DEFAULT 0 CHECK (total_solved >= 0),
  last_solved_at TIMESTAMPTZ
);

-- Backfill current submitted from existing doubts.
INSERT INTO public.student_doubt_stats (student_id, total_submitted, total_solved, last_solved_at)
SELECT
  d.student_id,
  COUNT(*)::int AS total_submitted,
  0,
  NULL
FROM public.doubts d
GROUP BY d.student_id
ON CONFLICT (student_id) DO UPDATE
SET total_submitted = EXCLUDED.total_submitted;

-- 6) Trigger: increment submitted count on doubt insert.
CREATE OR REPLACE FUNCTION public.increment_doubt_submitted()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.student_doubt_stats (student_id, total_submitted)
  VALUES (NEW.student_id, 1)
  ON CONFLICT (student_id)
  DO UPDATE SET total_submitted = public.student_doubt_stats.total_submitted + 1;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_doubt_submitted ON public.doubts;
CREATE TRIGGER trg_doubt_submitted
  AFTER INSERT ON public.doubts
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_doubt_submitted();

-- 7) RPC: mark solved and hard-delete doubt + messages.
CREATE OR REPLACE FUNCTION public.mark_doubt_solved_and_delete(p_doubt_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_student_id uuid;
  v_existing_status text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT student_id, status
  INTO v_student_id, v_existing_status
  FROM public.doubts
  WHERE id = p_doubt_id
  FOR UPDATE;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'doubt not found';
  END IF;

  IF NOT (v_uid = v_student_id OR public.is_admin() OR public.is_teacher()) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  UPDATE public.doubts
  SET
    status = 'solved',
    solved_by = v_uid,
    solved_at = now(),
    updated_at = now()
  WHERE id = p_doubt_id;

  INSERT INTO public.student_doubt_stats (student_id, total_solved, last_solved_at)
  VALUES (v_student_id, 1, now())
  ON CONFLICT (student_id)
  DO UPDATE
  SET
    total_solved = public.student_doubt_stats.total_solved + 1,
    last_solved_at = now();

  DELETE FROM public.doubts WHERE id = p_doubt_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_doubt_solved_and_delete(uuid) TO authenticated;

-- 8) RPC: schedule meeting (staff only), writes a system-like message as sender.
CREATE OR REPLACE FUNCTION public.schedule_doubt_meeting(
  p_doubt_id uuid,
  p_meeting_time timestamptz,
  p_meeting_link text,
  p_meeting_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_student_id uuid;
  v_payload text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF NOT (public.is_admin() OR public.is_teacher()) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT student_id INTO v_student_id
  FROM public.doubts
  WHERE id = p_doubt_id
  FOR UPDATE;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'doubt not found';
  END IF;

  UPDATE public.doubts
  SET
    resolution_type = 'meeting',
    status = 'meeting_scheduled',
    meeting_link = p_meeting_link,
    meeting_time = p_meeting_time,
    meeting_note = p_meeting_note,
    updated_at = now()
  WHERE id = p_doubt_id;

  v_payload := 'Meeting scheduled'
    || E'\nTime: ' || to_char(p_meeting_time AT TIME ZONE 'Asia/Dhaka', 'YYYY-MM-DD HH12:MI AM')
    || E'\nLink: ' || COALESCE(p_meeting_link, '')
    || CASE WHEN p_meeting_note IS NULL OR trim(p_meeting_note) = '' THEN '' ELSE E'\nNote: ' || p_meeting_note END;

  INSERT INTO public.doubt_messages (doubt_id, sender_id, message_type, content, body)
  VALUES (p_doubt_id, v_uid, 'text', v_payload, v_payload);
END;
$$;

GRANT EXECUTE ON FUNCTION public.schedule_doubt_meeting(uuid, timestamptz, text, text) TO authenticated;

-- 9) Notification trigger update to read from `doubts`.
CREATE OR REPLACE FUNCTION public.notify_doubt_message_recipients()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sid uuid;
BEGIN
  SELECT t.student_id INTO sid FROM public.doubts t WHERE t.id = NEW.doubt_id;
  IF sid IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.sender_id IS DISTINCT FROM sid THEN
    INSERT INTO public.notifications (user_id, title, body, type, action_route)
    VALUES (
      sid,
      'সন্দেহে নতুন উত্তর',
      COALESCE(NULLIF(trim(NEW.content::text), ''), NULLIF(trim(NEW.body::text), ''), 'নতুন মেসেজ'),
      'announcement',
      '/student/doubts/' || NEW.doubt_id::text
    );
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, action_route)
  SELECT
    u.id,
    'নতুন সন্দেহ মেসেজ',
    COALESCE(NULLIF(trim(NEW.content::text), ''), NULLIF(trim(NEW.body::text), ''), 'শিক্ষার্থীর মেসেজ'),
    'announcement',
    CASE u.role
      WHEN 'admin' THEN '/admin/doubts/' || NEW.doubt_id::text
      WHEN 'teacher' THEN '/teacher/doubts/' || NEW.doubt_id::text
      ELSE '/admin/doubts/' || NEW.doubt_id::text
    END
  FROM public.users u
  WHERE u.role IN ('admin', 'teacher')
    AND u.id IS DISTINCT FROM NEW.sender_id;

  RETURN NEW;
END;
$$;

-- 10) Keep old purge RPC working with new table name.
CREATE OR REPLACE FUNCTION public.purge_doubt_messages(p_doubt_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sid uuid;
BEGIN
  SELECT student_id INTO sid FROM public.doubts WHERE id = p_doubt_id;
  IF sid IS NULL THEN
    RAISE EXCEPTION 'doubt not found';
  END IF;
  IF NOT (auth.uid() = sid OR public.is_admin() OR public.is_teacher()) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  DELETE FROM public.doubt_messages WHERE doubt_id = p_doubt_id;
END;
$$;

-- 11) Peer-visibility helper uses new doubts table.
CREATE OR REPLACE FUNCTION public.user_visible_for_doubt_chat(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.doubts dt
    WHERE dt.student_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM public.doubt_messages dm
        WHERE dm.doubt_id = dt.id AND dm.sender_id = p_user_id
      )
  )
  OR EXISTS (
    SELECT 1 FROM public.doubts dt
    WHERE dt.student_id = p_user_id
      AND public.is_staff_doubt()
  );
$$;
