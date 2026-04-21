-- Student lifecycle controls
-- 1) remove from course
-- 2) pause student (manual)
-- 3) hard delete student with full related cleanup

DROP FUNCTION IF EXISTS public.admin_remove_student_from_course(UUID, UUID);
DROP FUNCTION IF EXISTS public.admin_pause_student(UUID);
DROP FUNCTION IF EXISTS public.admin_hard_delete_student(UUID);
DROP FUNCTION IF EXISTS public._delete_if_column_exists(TEXT, TEXT, UUID);

CREATE OR REPLACE FUNCTION public._delete_if_column_exists(
  p_table TEXT,
  p_column TEXT,
  p_student_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = p_table
      AND column_name = p_column
  ) THEN
    EXECUTE format('DELETE FROM public.%I WHERE %I = $1', p_table, p_column)
    USING p_student_id;
  END IF;
END;
$fn$;

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

  DELETE FROM public.exam_attempts ea
  USING public.exams e
  WHERE ea.exam_id = e.id
    AND ea.student_id = p_student_id
    AND e.course_id = p_course_id;

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

CREATE OR REPLACE FUNCTION public.admin_pause_student(
  p_student_id UUID
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

  UPDATE public.users
  SET is_active = false,
      updated_at = now()
  WHERE id = p_student_id
    AND role = 'student';

  UPDATE public.enrollments
  SET status = 'suspended'
  WHERE student_id = p_student_id
    AND status = 'active';

  RETURN jsonb_build_object('success', true);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_hard_delete_student(
  p_student_id UUID
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
    FROM public.users
    WHERE id = p_student_id
      AND role = 'student'
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'student_not_found'
    );
  END IF;

  -- Community / doubts / notifications
  PERFORM public._delete_if_column_exists('community_messages', 'sender_id', p_student_id);
  PERFORM public._delete_if_column_exists('community_members', 'user_id', p_student_id);
  PERFORM public._delete_if_column_exists('notifications', 'user_id', p_student_id);
  PERFORM public._delete_if_column_exists('doubt_messages', 'sender_id', p_student_id);
  PERFORM public._delete_if_column_exists('doubts', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('doubt_threads', 'student_id', p_student_id);

  -- Attendance / exam / results
  PERFORM public._delete_if_column_exists('attendance_records', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('results', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('exam_attempts', 'student_id', p_student_id);

  -- Payments domain
  PERFORM public._delete_if_column_exists('payment_ledger', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('payment_schedule', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('payment_dues', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('student_discounts', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('advance_balance', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('payments', 'student_id', p_student_id);

  -- Other student-linked domains
  PERFORM public._delete_if_column_exists('qbank_bookmarks', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('qbank_practice_sessions', 'student_id', p_student_id);
  PERFORM public._delete_if_column_exists('note_progress', 'student_id', p_student_id);

  -- Enrollment should be last among student-domain records.
  PERFORM public._delete_if_column_exists('enrollments', 'student_id', p_student_id);

  -- Finally delete the user profile row; auth.users row is cascade-linked.
  DELETE FROM public.users
  WHERE id = p_student_id
    AND role = 'student';

  RETURN jsonb_build_object('success', true);
END;
$fn$;

REVOKE ALL ON FUNCTION public._delete_if_column_exists(TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_remove_student_from_course(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_pause_student(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_hard_delete_student(UUID) TO authenticated, service_role;
