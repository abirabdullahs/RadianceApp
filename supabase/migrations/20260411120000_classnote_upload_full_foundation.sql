-- Classnote upload full foundation:
-- schema expansion, progress tracking, storage policies, publish notifications.

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS youtube_url TEXT,
  ADD COLUMN IF NOT EXISTS external_url TEXT,
  ADD COLUMN IF NOT EXISTS text_content TEXT,
  ADD COLUMN IF NOT EXISTS file_size_kb INT,
  ADD COLUMN IF NOT EXISTS duration_seconds INT,
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- Keep legacy `content` column backward-compatible; seed text_content where missing.
UPDATE public.notes
SET text_content = content
WHERE text_content IS NULL AND content IS NOT NULL;

ALTER TABLE public.notes DROP CONSTRAINT IF EXISTS notes_type_check;
ALTER TABLE public.notes ADD CONSTRAINT notes_type_check
  CHECK (type IN (
    'pdf', 'text', 'video_youtube', 'video_upload', 'image', 'link', 'lecture'
  ));

CREATE INDEX IF NOT EXISTS idx_notes_chapter_published_order
  ON public.notes(chapter_id, is_published, display_order, created_at);

CREATE TABLE IF NOT EXISTS public.note_progress (
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  note_id UUID NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  is_viewed BOOLEAN NOT NULL DEFAULT false,
  viewed_at TIMESTAMPTZ,
  video_watched_seconds INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(student_id, note_id)
);

CREATE INDEX IF NOT EXISTS idx_note_progress_student_updated
  ON public.note_progress(student_id, updated_at DESC);

ALTER TABLE public.note_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "note_progress_select_own_or_admin" ON public.note_progress;
CREATE POLICY "note_progress_select_own_or_admin" ON public.note_progress FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "note_progress_upsert_own_or_admin" ON public.note_progress;
CREATE POLICY "note_progress_upsert_own_or_admin" ON public.note_progress FOR INSERT
  WITH CHECK (student_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "note_progress_update_own_or_admin" ON public.note_progress;
CREATE POLICY "note_progress_update_own_or_admin" ON public.note_progress FOR UPDATE
  USING (student_id = auth.uid() OR public.is_admin())
  WITH CHECK (student_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "note_progress_delete_admin" ON public.note_progress;
CREATE POLICY "note_progress_delete_admin" ON public.note_progress FOR DELETE
  USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.increment_view_count(p_note_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_admin() OR public.student_enrolled_for_chapter((SELECT chapter_id FROM public.notes WHERE id = p_note_id)) THEN
    UPDATE public.notes
    SET view_count = COALESCE(view_count, 0) + 1,
        updated_at = now()
    WHERE id = p_note_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_note_progress(
  p_note_id UUID,
  p_is_viewed BOOLEAN DEFAULT false,
  p_video_watched_seconds INT DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.note_progress(student_id, note_id, is_viewed, viewed_at, video_watched_seconds, updated_at)
  VALUES (
    auth.uid(),
    p_note_id,
    p_is_viewed,
    CASE WHEN p_is_viewed THEN now() ELSE NULL END,
    GREATEST(p_video_watched_seconds, 0),
    now()
  )
  ON CONFLICT (student_id, note_id) DO UPDATE
  SET is_viewed = EXCLUDED.is_viewed OR public.note_progress.is_viewed,
      viewed_at = CASE
        WHEN EXCLUDED.is_viewed THEN COALESCE(public.note_progress.viewed_at, now())
        ELSE public.note_progress.viewed_at
      END,
      video_watched_seconds = GREATEST(public.note_progress.video_watched_seconds, EXCLUDED.video_watched_seconds),
      updated_at = now();
END;
$$;

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('notes', 'notes', true, 524288000)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit;

DROP POLICY IF EXISTS "notes_public_read" ON storage.objects;
CREATE POLICY "notes_public_read"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'notes');

DROP POLICY IF EXISTS "notes_admin_insert" ON storage.objects;
CREATE POLICY "notes_admin_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'notes' AND public.is_admin());

DROP POLICY IF EXISTS "notes_admin_update" ON storage.objects;
CREATE POLICY "notes_admin_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'notes' AND public.is_admin())
  WITH CHECK (bucket_id = 'notes' AND public.is_admin());

DROP POLICY IF EXISTS "notes_admin_delete" ON storage.objects;
CREATE POLICY "notes_admin_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'notes' AND public.is_admin());

CREATE OR REPLACE FUNCTION public.notify_note_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_course_id UUID;
  v_subject_name TEXT;
  v_chapter_name TEXT;
BEGIN
  IF NEW.is_published IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND COALESCE(OLD.is_published, false) = true THEN
    RETURN NEW;
  END IF;

  SELECT s.course_id, s.name, c.name
  INTO v_course_id, v_subject_name, v_chapter_name
  FROM public.chapters c
  JOIN public.subjects s ON s.id = c.subject_id
  WHERE c.id = NEW.chapter_id;

  INSERT INTO public.notifications(user_id, title, body, type, action_route, created_at)
  SELECT
    e.student_id,
    'নতুন ক্লাসনোট',
    COALESCE(v_subject_name, 'বিষয়') || ' — ' || COALESCE(v_chapter_name, 'অধ্যায়') || '-এ নতুন স্টাডি মেটেরিয়াল যোগ হয়েছে',
    'note',
    '/student/notes/' || NEW.chapter_id::text,
    now()
  FROM public.enrollments e
  WHERE e.course_id = v_course_id
    AND e.status = 'active';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_note_publish ON public.notes;
CREATE TRIGGER trg_notify_note_publish
  AFTER INSERT OR UPDATE ON public.notes
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_note_publish();

GRANT EXECUTE ON FUNCTION public.increment_view_count(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_note_progress(UUID, BOOLEAN, INT) TO authenticated, service_role;
