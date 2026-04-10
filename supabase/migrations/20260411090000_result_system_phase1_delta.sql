-- Result system phase-1 delta: enrich results schema, rank tie-break, and RLS alignment.

ALTER TABLE public.results
  ADD COLUMN IF NOT EXISTS exam_type text CHECK (exam_type IN ('online', 'offline')),
  ADD COLUMN IF NOT EXISTS total_correct integer,
  ADD COLUMN IF NOT EXISTS total_wrong integer,
  ADD COLUMN IF NOT EXISTS total_skipped integer,
  ADD COLUMN IF NOT EXISTS negative_deduction numeric(6,2),
  ADD COLUMN IF NOT EXISTS time_taken_seconds integer,
  ADD COLUMN IF NOT EXISTS remarks text,
  ADD COLUMN IF NOT EXISTS is_published boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS is_absent boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.results r
SET exam_type = e.exam_mode
FROM public.exams e
WHERE e.id = r.exam_id
  AND (r.exam_type IS NULL OR r.exam_type <> e.exam_mode);

UPDATE public.results r
SET is_published = true
FROM public.exams e
WHERE e.id = r.exam_id
  AND (
    r.published_at IS NOT NULL
    OR e.status = 'result_published'
  );

CREATE OR REPLACE FUNCTION public.calculate_exam_ranks(p_exam_id UUID)
RETURNS VOID
LANGUAGE SQL
AS $$
  WITH ranked AS (
    SELECT
      id,
      DENSE_RANK() OVER (
        ORDER BY score DESC, time_taken_seconds ASC NULLS LAST
      )::int AS rank
    FROM public.results
    WHERE exam_id = p_exam_id
      AND COALESCE(is_published, false) = true
      AND COALESCE(is_absent, false) = false
  )
  UPDATE public.results
  SET rank = ranked.rank
  FROM ranked
  WHERE public.results.id = ranked.id;

  UPDATE public.results
  SET rank = NULL
  WHERE exam_id = p_exam_id
    AND (COALESCE(is_published, false) = false OR COALESCE(is_absent, false) = true);
$$;

DROP POLICY IF EXISTS "results_select" ON public.results;

CREATE POLICY "results_select" ON public.results FOR SELECT
USING (
  public.is_admin()
  OR (
    is_published = true
    AND EXISTS (
      SELECT 1
      FROM public.exams ex
      WHERE ex.id = results.exam_id
        AND ex.status = 'result_published'
        AND public.student_enrolled_in_course(ex.course_id)
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_results_exam_published_rank
  ON public.results (exam_id, is_published, rank);

CREATE INDEX IF NOT EXISTS idx_results_student_published_at_desc
  ON public.results (student_id, published_at DESC);
