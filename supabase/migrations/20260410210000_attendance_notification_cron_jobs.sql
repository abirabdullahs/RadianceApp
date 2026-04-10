-- Automatic attendance notification scheduling (S3.5)
-- Weekly: queue student attendance summary notifications
-- Monthly: queue warning notifications + guardian SMS (if enabled in attendance_settings)

CREATE OR REPLACE FUNCTION public.run_attendance_weekly_batch(
  p_course_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start DATE := (CURRENT_DATE - INTERVAL '6 day')::DATE;
  v_end DATE := CURRENT_DATE;
  v_count INT := 0;
BEGIN
  WITH session_scope AS (
    SELECT s.id, s.course_id
    FROM public.attendance_sessions s
    WHERE s.session_date BETWEEN v_start AND v_end
      AND (p_course_id IS NULL OR s.course_id = p_course_id)
  ),
  student_stats AS (
    SELECT
      r.student_id,
      ss.course_id,
      COUNT(*)::INT AS total_classes,
      COUNT(*) FILTER (WHERE r.status IN ('present', 'late'))::INT AS present_classes
    FROM public.attendance_records r
    JOIN session_scope ss ON ss.id = r.session_id
    GROUP BY r.student_id, ss.course_id
  ),
  notif_rows AS (
    SELECT
      st.student_id AS user_id,
      'সাপ্তাহিক উপস্থিতি আপডেট'::TEXT AS title,
      ('এই সপ্তাহে তোমার উপস্থিতি '
        || COALESCE(ROUND((st.present_classes * 100.0) / NULLIF(st.total_classes, 0), 0), 0)::TEXT
        || '%। চালিয়ে যাও! 💪')::TEXT AS body,
      'attendance'::TEXT AS type,
      '/student/attendance'::TEXT AS action_route
    FROM student_stats st
    WHERE st.total_classes > 0
  )
  INSERT INTO public.notifications (user_id, title, body, type, action_route, fcm_sent)
  SELECT n.user_id, n.title, n.body, n.type, n.action_route, false
  FROM notif_rows n;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'job', 'weekly_attendance',
    'start_date', v_start,
    'end_date', v_end,
    'queued_notifications', v_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.run_attendance_monthly_warning_batch(
  p_month DATE DEFAULT NULL,
  p_course_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month DATE := DATE_TRUNC('month', COALESCE(p_month, CURRENT_DATE))::DATE;
  v_start DATE := v_month;
  v_end DATE := (DATE_TRUNC('month', v_month) + INTERVAL '1 month - 1 day')::DATE;
  v_threshold INT := 75;
  v_auto_sms BOOLEAN := false;
  v_template TEXT := 'প্রিয় অভিভাবক, {name} এর উপস্থিতি {month} মাসে {percentage}% (সতর্কতা সীমা {threshold}%)। অনুগ্রহ করে নিয়মিত ক্লাসে উপস্থিতি নিশ্চিত করুন। — Radiance Coaching Center';
  v_notif_count INT := 0;
  v_sms_count INT := 0;
BEGIN
  SELECT
    COALESCE(s.warning_threshold_pct, 75),
    COALESCE(s.auto_sms_enabled, false)
  INTO v_threshold, v_auto_sms
  FROM public.attendance_settings s
  WHERE s.singleton_key = 1;

  SELECT t.body
  INTO v_template
  FROM public.sms_templates t
  WHERE t.template_key = 'attendance_warning_guardian'
    AND t.is_active = true
  LIMIT 1;

  WITH session_scope AS (
    SELECT s.id, s.course_id
    FROM public.attendance_sessions s
    WHERE s.session_date BETWEEN v_start AND v_end
      AND (p_course_id IS NULL OR s.course_id = p_course_id)
  ),
  student_stats AS (
    SELECT
      r.student_id,
      ss.course_id,
      COUNT(*)::INT AS total_classes,
      COUNT(*) FILTER (WHERE r.status IN ('present', 'late'))::INT AS present_classes
    FROM public.attendance_records r
    JOIN session_scope ss ON ss.id = r.session_id
    GROUP BY r.student_id, ss.course_id
  ),
  warning_rows AS (
    SELECT
      st.student_id,
      u.full_name_bn,
      u.guardian_phone,
      st.total_classes,
      st.present_classes,
      ROUND((st.present_classes * 100.0) / NULLIF(st.total_classes, 0), 1) AS pct
    FROM student_stats st
    JOIN public.users u ON u.id = st.student_id
    WHERE st.total_classes > 0
      AND ROUND((st.present_classes * 100.0) / NULLIF(st.total_classes, 0), 1) < v_threshold
  )
  INSERT INTO public.notifications (user_id, title, body, type, action_route, fcm_sent)
  SELECT
    w.student_id,
    'উপস্থিতি সতর্কতা',
    ('সতর্কতা! তোমার উপস্থিতি ' || w.pct::TEXT || '% — ' || v_threshold::TEXT || '%-এর নিচে।'),
    'attendance',
    '/student/attendance',
    false
  FROM warning_rows w;

  GET DIAGNOSTICS v_notif_count = ROW_COUNT;

  IF v_auto_sms THEN
    WITH session_scope AS (
      SELECT s.id, s.course_id
      FROM public.attendance_sessions s
      WHERE s.session_date BETWEEN v_start AND v_end
        AND (p_course_id IS NULL OR s.course_id = p_course_id)
    ),
    student_stats AS (
      SELECT
        r.student_id,
        ss.course_id,
        COUNT(*)::INT AS total_classes,
        COUNT(*) FILTER (WHERE r.status IN ('present', 'late'))::INT AS present_classes
      FROM public.attendance_records r
      JOIN session_scope ss ON ss.id = r.session_id
      GROUP BY r.student_id, ss.course_id
    ),
    warning_rows AS (
      SELECT
        st.student_id,
        u.full_name_bn,
        u.guardian_phone,
        ROUND((st.present_classes * 100.0) / NULLIF(st.total_classes, 0), 1) AS pct
      FROM student_stats st
      JOIN public.users u ON u.id = st.student_id
      WHERE st.total_classes > 0
        AND ROUND((st.present_classes * 100.0) / NULLIF(st.total_classes, 0), 1) < v_threshold
        AND u.guardian_phone IS NOT NULL
        AND LENGTH(TRIM(u.guardian_phone)) > 0
    )
    INSERT INTO public.sms_logs (to_phone, message, gateway, status)
    SELECT
      TRIM(w.guardian_phone),
      REPLACE(
        REPLACE(
          REPLACE(
            REPLACE(v_template, '{name}', COALESCE(w.full_name_bn, 'শিক্ষার্থী')),
            '{month}', TO_CHAR(v_month, 'FMMonth YYYY')
          ),
          '{percentage}', w.pct::TEXT
        ),
        '{threshold}', v_threshold::TEXT
      ),
      'ssl_wireless',
      'pending'
    FROM warning_rows w;

    GET DIAGNOSTICS v_sms_count = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'job', 'monthly_attendance_warning',
    'month', v_month,
    'threshold_pct', v_threshold,
    'auto_sms_enabled', v_auto_sms,
    'queued_notifications', v_notif_count,
    'queued_sms', v_sms_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_attendance_weekly_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_attendance_weekly_batch(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.run_attendance_monthly_warning_batch(DATE, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_attendance_monthly_warning_batch(DATE, UUID) TO service_role;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available, skipping attendance cron setup: %', SQLERRM;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      PERFORM cron.unschedule('attendance_weekly_summary_job');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
    BEGIN
      PERFORM cron.unschedule('attendance_monthly_warning_job');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    -- Every Friday at 21:00 server time.
    PERFORM cron.schedule(
      'attendance_weekly_summary_job',
      '0 21 * * 5',
      $cron$SELECT public.run_attendance_weekly_batch(NULL);$cron$
    );

    -- 2nd day of each month at 09:00 server time.
    PERFORM cron.schedule(
      'attendance_monthly_warning_job',
      '0 9 2 * *',
      $cron$SELECT public.run_attendance_monthly_warning_batch(NULL, NULL);$cron$
    );
  END IF;
END $$;
