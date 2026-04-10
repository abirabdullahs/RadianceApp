-- Student ID format: RCC + last 9 digits of phone
-- Also allow students to view published exam leaderboards (results rows of enrolled exam).

CREATE OR REPLACE FUNCTION public.student_id_from_phone(p_phone text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  d text := regexp_replace(COALESCE(p_phone, ''), '\D', '', 'g');
BEGIN
  IF length(d) < 9 THEN
    RAISE EXCEPTION 'Phone must contain at least 9 digits';
  END IF;
  RETURN 'RCC' || right(d, 9);
END;
$$;

CREATE OR REPLACE FUNCTION public.set_student_id_from_phone()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role = 'student' THEN
    NEW.student_id := public.student_id_from_phone(NEW.phone);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_student_id ON public.users;
CREATE TRIGGER set_student_id_from_phone_trg
  BEFORE INSERT OR UPDATE OF phone, role ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.set_student_id_from_phone();

-- Backfill existing student ids to the new RCC######### format.
UPDATE public.users
SET student_id = public.student_id_from_phone(phone)
WHERE role = 'student';

-- Replace results select policy so students can view leaderboard rows
-- for exams in courses they are enrolled in, once result is published.
DROP POLICY IF EXISTS "results_select" ON public.results;

CREATE POLICY "results_select" ON public.results FOR SELECT
  USING (
    public.is_admin()
    OR (
      EXISTS (
        SELECT 1
        FROM public.exams ex
        WHERE ex.id = results.exam_id
          AND ex.status = 'result_published'
          AND public.student_enrolled_in_course(ex.course_id)
      )
    )
  );
