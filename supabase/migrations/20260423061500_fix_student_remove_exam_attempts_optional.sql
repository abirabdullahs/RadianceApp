-- Fix admin remove-student flow for databases that do not have `exam_attempts`.
-- Keep cleanup behavior when table exists; skip safely when it does not.

CREATE OR REPLACE FUNCTION public.admin_remove_student_from_course(
  p_student_id UUID,
  p_course_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin only';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.enrollments
    WHERE student_id = p_student_id
      AND course_id = p_course_id
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'enrollment_not_found'
    );
  END IF;

  DELETE FROM public.payment_schedule
  WHERE student_id = p_student_id
    AND course_id = p_course_id;

  DELETE FROM public.payment_ledger
  WHERE student_id = p_student_id
    AND course_id = p_course_id;

  DELETE FROM public.payment_dues
  WHERE student_id = p_student_id
    AND course_id = p_course_id;

  DELETE FROM public.student_discounts
  WHERE student_id = p_student_id
    AND course_id = p_course_id;

  DELETE FROM public.advance_balance
  WHERE student_id = p_student_id
    AND course_id = p_course_id;

  DELETE FROM public.payments
  WHERE student_id = p_student_id
    AND course_id = p_course_id;

  DELETE FROM public.attendance_records ar
  USING public.attendance_sessions s
  WHERE ar.session_id = s.id
    AND ar.student_id = p_student_id
    AND s.course_id = p_course_id;

  DELETE FROM public.results r
  USING public.exams e
  WHERE r.exam_id = e.id
    AND r.student_id = p_student_id
    AND e.course_id = p_course_id;

  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'exam_attempts'
  ) THEN
    DELETE FROM public.exam_attempts ea
    USING public.exams e
    WHERE ea.exam_id = e.id
      AND ea.student_id = p_student_id
      AND e.course_id = p_course_id;
  END IF;

  DELETE FROM public.community_members cm
  USING public.community_groups g
  WHERE cm.group_id = g.id
    AND cm.user_id = p_student_id
    AND g.course_id = p_course_id;

  DELETE FROM public.community_messages m
  USING public.community_groups g
  WHERE m.group_id = g.id
    AND m.sender_id = p_student_id
    AND g.course_id = p_course_id;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'doubts'
      AND column_name = 'course_id'
  ) THEN
    DELETE FROM public.doubts
    WHERE student_id = p_student_id
      AND course_id = p_course_id;
  ELSE
    DELETE FROM public.doubts
    WHERE student_id = p_student_id;
  END IF;

  DELETE FROM public.enrollments
  WHERE student_id = p_student_id
    AND course_id = p_course_id;

  RETURN jsonb_build_object('success', true);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.admin_remove_student_from_course(UUID, UUID)
TO authenticated, service_role;
