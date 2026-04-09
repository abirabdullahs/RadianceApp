-- One messenger-style group per course; auto-create on course insert; auto-add/remove
-- students via enrollments (SECURITY DEFINER triggers bypass RLS on community_members).

CREATE UNIQUE INDEX IF NOT EXISTS idx_community_groups_one_course
  ON public.community_groups (course_id)
  WHERE course_id IS NOT NULL;

-- New course → one group (name mirrors course).
CREATE OR REPLACE FUNCTION public.trg_course_create_community_group()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.community_groups (course_id, name, description)
  SELECT
    NEW.id,
    trim(COALESCE(NEW.name, 'কোর্স')) || ' — চ্যাট',
    'কোর্স গ্রুপ চ্যাট'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.community_groups g WHERE g.course_id = NEW.id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_course_create_community_group ON public.courses;
CREATE TRIGGER trg_course_create_community_group
  AFTER INSERT ON public.courses
  FOR EACH ROW
  EXECUTE PROCEDURE public.trg_course_create_community_group();

-- Enrollment → sync community_members (students must be members for RLS on messages).
CREATE OR REPLACE FUNCTION public.trg_enrollment_sync_community_member()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.community_members cm
    USING public.community_groups g
    WHERE cm.group_id = g.id
      AND g.course_id = OLD.course_id
      AND cm.user_id = OLD.student_id;
    RETURN OLD;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'active' THEN
      INSERT INTO public.community_members (group_id, user_id)
      SELECT g.id, NEW.student_id
      FROM public.community_groups g
      WHERE g.course_id = NEW.course_id
      ON CONFLICT (group_id, user_id) DO NOTHING;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'active' AND NEW.status IS DISTINCT FROM 'active' THEN
      DELETE FROM public.community_members cm
      USING public.community_groups g
      WHERE cm.group_id = g.id
        AND g.course_id = NEW.course_id
        AND cm.user_id = NEW.student_id;
    ELSIF NEW.status = 'active' AND OLD.status IS DISTINCT FROM 'active' THEN
      INSERT INTO public.community_members (group_id, user_id)
      SELECT g.id, NEW.student_id
      FROM public.community_groups g
      WHERE g.course_id = NEW.course_id
      ON CONFLICT (group_id, user_id) DO NOTHING;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enrollment_sync_community_member ON public.enrollments;
CREATE TRIGGER trg_enrollment_sync_community_member
  AFTER INSERT OR UPDATE OR DELETE ON public.enrollments
  FOR EACH ROW
  EXECUTE PROCEDURE public.trg_enrollment_sync_community_member();

-- Backfill: group per existing course.
INSERT INTO public.community_groups (course_id, name, description)
SELECT
  c.id,
  trim(COALESCE(c.name, 'কোর্স')) || ' — চ্যাট',
  'কোর্স গ্রুপ চ্যাট'
FROM public.courses c
WHERE NOT EXISTS (SELECT 1 FROM public.community_groups g WHERE g.course_id = c.id);

-- Backfill: members for active enrollments.
INSERT INTO public.community_members (group_id, user_id)
SELECT g.id, e.student_id
FROM public.enrollments e
JOIN public.community_groups g ON g.course_id = e.course_id
WHERE e.status = 'active'
ON CONFLICT (group_id, user_id) DO NOTHING;
