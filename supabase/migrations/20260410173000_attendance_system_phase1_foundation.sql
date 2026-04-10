-- Attendance system phase-1 foundation upgrade
-- Goal: extend existing attendance schema to match plan/06_attendance_system.md
-- while keeping backward compatibility with current app usage (`date` column).

-- =============================
-- attendance_sessions upgrades
-- =============================
ALTER TABLE public.attendance_sessions
  ADD COLUMN IF NOT EXISTS session_date date,
  ADD COLUMN IF NOT EXISTS total_students integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS present_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS absent_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_completed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS note text;

-- Backfill from legacy column.
UPDATE public.attendance_sessions
SET session_date = date
WHERE session_date IS NULL;

-- Keep future rows valid.
ALTER TABLE public.attendance_sessions
  ALTER COLUMN session_date SET DEFAULT CURRENT_DATE;

-- Make sure both columns stay in sync for old/new code paths.
CREATE OR REPLACE FUNCTION public.sync_attendance_session_dates()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.session_date IS NULL AND NEW.date IS NOT NULL THEN
    NEW.session_date := NEW.date;
  ELSIF NEW.date IS NULL AND NEW.session_date IS NOT NULL THEN
    NEW.date := NEW.session_date;
  ELSIF NEW.session_date IS NOT NULL AND NEW.date IS NOT NULL THEN
    NEW.date := NEW.session_date;
  ELSE
    NEW.session_date := CURRENT_DATE;
    NEW.date := NEW.session_date;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_attendance_session_dates ON public.attendance_sessions;
CREATE TRIGGER trg_sync_attendance_session_dates
BEFORE INSERT OR UPDATE ON public.attendance_sessions
FOR EACH ROW
EXECUTE FUNCTION public.sync_attendance_session_dates();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'attendance_sessions_course_id_session_date_key'
      AND conrelid = 'public.attendance_sessions'::regclass
  ) THEN
    ALTER TABLE public.attendance_sessions
      ADD CONSTRAINT attendance_sessions_course_id_session_date_key
      UNIQUE (course_id, session_date);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_course_date
  ON public.attendance_sessions (course_id, session_date);

-- =============================
-- attendance_records upgrades
-- =============================
ALTER TABLE public.attendance_records
  ADD COLUMN IF NOT EXISTS marked_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_attendance_records_session_id
  ON public.attendance_records (session_id);

CREATE INDEX IF NOT EXISTS idx_attendance_records_student_id
  ON public.attendance_records (student_id);

-- =============================
-- attendance_edit_log upgrades
-- =============================
ALTER TABLE public.attendance_edit_log
  ADD COLUMN IF NOT EXISTS reason text;

CREATE INDEX IF NOT EXISTS idx_attendance_edit_log_record_id
  ON public.attendance_edit_log (record_id);

-- =============================================
-- Maintain rollup counts on session automatically
-- =============================================
CREATE OR REPLACE FUNCTION public.refresh_attendance_session_counts(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_total integer := 0;
  v_present integer := 0;
  v_absent integer := 0;
BEGIN
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status IN ('present', 'late'))::int,
    COUNT(*) FILTER (WHERE status = 'absent')::int
  INTO v_total, v_present, v_absent
  FROM public.attendance_records
  WHERE session_id = p_session_id;

  UPDATE public.attendance_sessions
  SET
    total_students = v_total,
    present_count = v_present,
    absent_count = v_absent
  WHERE id = p_session_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_refresh_attendance_counts()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.refresh_attendance_session_counts(OLD.session_id);
  ELSE
    PERFORM public.refresh_attendance_session_counts(NEW.session_id);
    IF TG_OP = 'UPDATE' AND OLD.session_id <> NEW.session_id THEN
      PERFORM public.refresh_attendance_session_counts(OLD.session_id);
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_attendance_records_refresh_counts ON public.attendance_records;
CREATE TRIGGER trg_attendance_records_refresh_counts
AFTER INSERT OR UPDATE OR DELETE ON public.attendance_records
FOR EACH ROW
EXECUTE FUNCTION public.trg_refresh_attendance_counts();
