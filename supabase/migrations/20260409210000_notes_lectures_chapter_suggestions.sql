-- Lectures: use `notes` with type `lecture` (markdown in `content`, optional video in `file_url`).
-- Chapter suggestions: `suggestions.chapter_id` + `pdf_url` (markdown in `content`).

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS display_order INT NOT NULL DEFAULT 0;

ALTER TABLE public.notes DROP CONSTRAINT IF EXISTS notes_type_check;
ALTER TABLE public.notes ADD CONSTRAINT notes_type_check
  CHECK (type IN (
    'pdf', 'text', 'video_youtube', 'video_upload', 'image', 'link', 'lecture'
  ));

ALTER TABLE public.suggestions
  ADD COLUMN IF NOT EXISTS chapter_id UUID REFERENCES public.chapters(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS pdf_url TEXT;

CREATE INDEX IF NOT EXISTS idx_suggestions_chapter_id ON public.suggestions(chapter_id)
  WHERE chapter_id IS NOT NULL;

DROP POLICY IF EXISTS "suggestions_read" ON public.suggestions;

CREATE POLICY "suggestions_read" ON public.suggestions FOR SELECT
  USING (
    public.is_admin()
    OR (
      is_published = true
      AND (
        (chapter_id IS NOT NULL AND public.student_enrolled_for_chapter(chapter_id))
        OR (
          chapter_id IS NULL
          AND course_id IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM public.enrollments e
            WHERE e.student_id = auth.uid()
              AND e.course_id = suggestions.course_id
              AND e.status = 'active'
          )
        )
        OR (chapter_id IS NULL AND course_id IS NULL)
      )
    )
  );
