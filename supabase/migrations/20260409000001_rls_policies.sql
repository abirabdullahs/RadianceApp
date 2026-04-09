-- Row Level Security for Radiance (see plan/03_database_roadmap.md)

-- Role checks use JWT only (see 20260409170000_is_admin_jwt_and_sync_auth.sql).
-- Never SELECT public.users here — avoids RLS infinite recursion on users.
-- Invoker-only (no SECURITY DEFINER) so auth.jwt() matches the session; used on non-users tables.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin',
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin',
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.is_student()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'student',
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'student',
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.student_enrolled_in_course(p_course_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.enrollments
    WHERE student_id = auth.uid() AND course_id = p_course_id AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.student_enrolled_for_chapter(p_chapter_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chapters c
    JOIN public.subjects s ON s.id = c.subject_id
    JOIN public.enrollments e ON e.course_id = s.course_id
    WHERE c.id = p_chapter_id AND e.student_id = auth.uid() AND e.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.student_in_community_group(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_members
    WHERE group_id = p_group_id AND user_id = auth.uid()
  );
$$;

-- USERS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- public.users policies must NOT call is_admin() — any function call can re-trigger 42P17 on this table.
-- Use inline JWT checks only. Keep role in sync: 20260409170000_is_admin_jwt_and_sync_auth.sql
CREATE POLICY "users_select_own" ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "users_select_as_admin" ON public.users FOR SELECT
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "users_insert_own" ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_insert_admin" ON public.users FOR INSERT
  WITH CHECK (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "users_update_own" ON public.users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_as_admin" ON public.users FOR UPDATE
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  )
  WITH CHECK (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "users_delete_admin" ON public.users FOR DELETE
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

-- COURSES (public read active for marketing)
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "courses_select_anon_active" ON public.courses FOR SELECT TO anon
  USING (is_active = true);

CREATE POLICY "courses_select_auth" ON public.courses FOR SELECT TO authenticated
  USING (is_active = true OR public.is_admin());

CREATE POLICY "courses_write_admin" ON public.courses FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- SUBJECTS / CHAPTERS
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subjects_read" ON public.subjects FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.courses c WHERE c.id = subjects.course_id AND c.is_active = true)
  );

CREATE POLICY "subjects_write_admin" ON public.subjects FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "chapters_read" ON public.chapters FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.subjects s
      JOIN public.courses c ON c.id = s.course_id
      WHERE s.id = chapters.subject_id AND c.is_active = true
    )
  );

CREATE POLICY "chapters_write_admin" ON public.chapters FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- NOTES
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notes_read" ON public.notes FOR SELECT
  USING (
    public.is_admin()
    OR (is_published = true AND public.student_enrolled_for_chapter(chapter_id))
  );

CREATE POLICY "notes_write_admin" ON public.notes FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ENROLLMENTS
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "enrollments_select" ON public.enrollments FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "enrollments_write_admin" ON public.enrollments FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "enrollments_update_admin" ON public.enrollments FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "enrollments_delete_admin" ON public.enrollments FOR DELETE
  USING (public.is_admin());

-- PAYMENTS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_dues ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payments_select" ON public.payments FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "payments_write_admin" ON public.payments FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "payments_update_admin" ON public.payments FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "payments_delete_admin" ON public.payments FOR DELETE
  USING (public.is_admin());

CREATE POLICY "dues_select" ON public.payment_dues FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "dues_write_admin" ON public.payment_dues FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ATTENDANCE
ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_edit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "att_sessions_select" ON public.attendance_sessions FOR SELECT
  USING (
    public.is_admin()
    OR public.student_enrolled_in_course(course_id)
  );

CREATE POLICY "att_sessions_write_admin" ON public.attendance_sessions FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "att_records_select" ON public.attendance_records FOR SELECT
  USING (
    public.is_admin()
    OR student_id = auth.uid()
  );

CREATE POLICY "att_records_write_admin" ON public.attendance_records FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "att_edit_log_admin" ON public.attendance_edit_log FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- EXAMS / QUESTIONS / SUBMISSIONS / RESULTS
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exams_select" ON public.exams FOR SELECT
  USING (
    public.is_admin()
    OR (public.student_enrolled_in_course(course_id) AND status IN ('scheduled','live','ended','result_published'))
  );

CREATE POLICY "exams_write_admin" ON public.exams FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "questions_select" ON public.questions FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.exams e
      WHERE e.id = questions.exam_id
        AND public.student_enrolled_in_course(e.course_id)
        AND e.status IN ('scheduled','live','ended','result_published')
    )
  );

CREATE POLICY "questions_write_admin" ON public.questions FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "exam_sub_select" ON public.exam_submissions FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "exam_sub_insert_own" ON public.exam_submissions FOR INSERT
  WITH CHECK (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "exam_sub_update" ON public.exam_submissions FOR UPDATE
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "results_select" ON public.results FOR SELECT
  USING (
    public.is_admin()
    OR (student_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.exams ex WHERE ex.id = results.exam_id AND ex.status = 'result_published'
    ))
  );

CREATE POLICY "results_write_admin" ON public.results FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- QBANK
ALTER TABLE public.qbank_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "qbank_read" ON public.qbank_questions FOR SELECT
  USING (is_published = true OR public.is_admin());

CREATE POLICY "qbank_write_admin" ON public.qbank_questions FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "qbank_bm_select" ON public.qbank_bookmarks FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "qbank_bm_write_own" ON public.qbank_bookmarks FOR INSERT
  WITH CHECK (student_id = auth.uid());

CREATE POLICY "qbank_bm_delete_own" ON public.qbank_bookmarks FOR DELETE
  USING (student_id = auth.uid());

-- COMMUNITY
ALTER TABLE public.community_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cgroups_select" ON public.community_groups FOR SELECT
  USING (
    public.is_admin()
    OR (course_id IS NOT NULL AND public.student_enrolled_in_course(course_id))
  );

CREATE POLICY "cgroups_write_admin" ON public.community_groups FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "cmembers_select" ON public.community_members FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "cmembers_write_admin" ON public.community_members FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "cmsg_select" ON public.community_messages FOR SELECT
  USING (public.is_admin() OR public.student_in_community_group(group_id));

CREATE POLICY "cmsg_insert" ON public.community_messages FOR INSERT
  WITH CHECK (
    public.is_admin()
    OR (sender_id = auth.uid() AND public.student_in_community_group(group_id))
  );

CREATE POLICY "cmsg_update" ON public.community_messages FOR UPDATE
  USING (public.is_admin() OR sender_id = auth.uid());

-- NOTIFICATIONS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_select" ON public.notifications FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin() OR (user_id IS NULL AND public.is_admin()));

CREATE POLICY "notif_insert_admin" ON public.notifications FOR INSERT
  WITH CHECK (public.is_admin() OR user_id = auth.uid());

CREATE POLICY "notif_update_own" ON public.notifications FOR UPDATE
  USING (user_id = auth.uid() OR public.is_admin());

-- SMS logs: admin only
ALTER TABLE public.sms_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sms_logs_admin" ON public.sms_logs FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- COMPLAINTS
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

CREATE POLICY "complaints_select" ON public.complaints FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "complaints_insert_student" ON public.complaints FOR INSERT
  WITH CHECK (student_id = auth.uid());

CREATE POLICY "complaints_update" ON public.complaints FOR UPDATE
  USING (student_id = auth.uid() OR public.is_admin());

-- HOME CONTENT (public read)
ALTER TABLE public.home_content ENABLE ROW LEVEL SECURITY;

CREATE POLICY "home_read_anon" ON public.home_content FOR SELECT TO anon
  USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));

CREATE POLICY "home_read_auth" ON public.home_content FOR SELECT TO authenticated
  USING (is_active = true OR public.is_admin());

CREATE POLICY "home_write_admin" ON public.home_content FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- SUGGESTIONS
ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suggestion_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "suggestions_read" ON public.suggestions FOR SELECT
  USING (is_published = true OR public.is_admin());

CREATE POLICY "suggestions_write_admin" ON public.suggestions FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "sugg_likes_select" ON public.suggestion_likes FOR SELECT
  USING (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "sugg_likes_write" ON public.suggestion_likes FOR INSERT
  WITH CHECK (student_id = auth.uid());

CREATE POLICY "sugg_likes_delete" ON public.suggestion_likes FOR DELETE
  USING (student_id = auth.uid());

-- Grant RPC to authenticated
GRANT EXECUTE ON FUNCTION public.calculate_exam_ranks(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_exam_ranks(uuid) TO service_role;
