-- PostgreSQL only — run this file as-is in the SQL Editor (do not paste Dart/Flutter .dart files here).
-- Performance: indexes aligned with common Flutter query patterns (notifications, users, enrollments, exams, notes path, community chat).

CREATE INDEX IF NOT EXISTS idx_notifications_user_created_at
  ON public.notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id)
  WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_users_role_created_at
  ON public.users (role, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_enrollments_student_status
  ON public.enrollments (student_id, status);

CREATE INDEX IF NOT EXISTS idx_enrollments_course_student
  ON public.enrollments (course_id, student_id);

CREATE INDEX IF NOT EXISTS idx_exams_course_start
  ON public.exams (course_id, start_time DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_exams_status
  ON public.exams (status);

CREATE INDEX IF NOT EXISTS idx_subjects_course
  ON public.subjects (course_id);

CREATE INDEX IF NOT EXISTS idx_chapters_subject
  ON public.chapters (subject_id);

CREATE INDEX IF NOT EXISTS idx_community_messages_group_created
  ON public.community_messages (group_id, created_at DESC);
