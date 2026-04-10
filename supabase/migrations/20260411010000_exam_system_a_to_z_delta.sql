-- Exam system A-Z additive delta
-- Keeps backward compatibility with existing exam phase migrations.

-- ---------------------------------------------
-- EXAMS additions (online + offline parity)
-- ---------------------------------------------
ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS description TEXT;

ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS exam_date DATE;

ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS venue TEXT;

ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS marks_per_question NUMERIC(4,2) DEFAULT 1;

-- ---------------------------------------------
-- RESULTS additions (unified online + offline)
-- ---------------------------------------------
ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS exam_type VARCHAR(10)
  CHECK (exam_type IN ('online', 'offline'));

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS total_correct INT;

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS total_wrong INT;

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS total_skipped INT;

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS negative_deduction NUMERIC(6,2) DEFAULT 0;

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS grade_point NUMERIC(3,1);

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS time_taken_seconds INT;

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS remarks TEXT;

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

ALTER TABLE public.results
ADD COLUMN IF NOT EXISTS is_absent BOOLEAN NOT NULL DEFAULT false;

-- Backfill existing rows
UPDATE public.results r
SET
  exam_type = COALESCE(r.exam_type, ex.exam_mode),
  is_published = COALESCE(r.is_published, true)
FROM public.exams ex
WHERE ex.id = r.exam_id
  AND (r.exam_type IS NULL OR r.is_published IS NULL);

-- Rank should skip absent/unpublished rows
CREATE OR REPLACE FUNCTION public.calculate_exam_ranks(p_exam_id UUID)
RETURNS VOID
LANGUAGE SQL
AS $$
  WITH ranked AS (
    SELECT
      id,
      DENSE_RANK() OVER (ORDER BY score DESC)::INT AS next_rank
    FROM public.results
    WHERE exam_id = p_exam_id
      AND COALESCE(is_published, false) = true
      AND COALESCE(is_absent, false) = false
  )
  UPDATE public.results t
  SET rank = ranked.next_rank
  FROM ranked
  WHERE t.id = ranked.id;

  UPDATE public.results
  SET rank = NULL
  WHERE exam_id = p_exam_id
    AND (COALESCE(is_published, false) = false OR COALESCE(is_absent, false) = true);
$$;

-- Keep leaderboard visibility restricted to published rows.
DROP POLICY IF EXISTS "results_select" ON public.results;

CREATE POLICY "results_select" ON public.results FOR SELECT
  USING (
    public.is_admin()
    OR (
      COALESCE(results.is_published, false) = true
      AND EXISTS (
        SELECT 1
        FROM public.exams ex
        WHERE ex.id = results.exam_id
          AND ex.status = 'result_published'
          AND public.student_enrolled_in_course(ex.course_id)
      )
    )
  );
