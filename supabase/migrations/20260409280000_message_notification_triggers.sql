-- In-app notifications when community / doubt messages are posted.
-- SECURITY DEFINER functions run as owner and bypass RLS for inserts.

CREATE OR REPLACE FUNCTION public.notify_community_message_recipients()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(NEW.is_deleted, false) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, action_route)
  SELECT
    cm.user_id,
    'নতুন মেসেজ',
    COALESCE(
      NULLIF(trim(NEW.content::text), ''),
      CASE NEW.type
        WHEN 'image' THEN 'ছবি পাঠানো হয়েছে'
        WHEN 'file' THEN 'ফাইল পাঠানো হয়েছে'
        ELSE 'কমিউনিটি চ্যাট'
      END
    ),
    'announcement',
    '/student/community/' || NEW.group_id::text
  FROM public.community_members cm
  WHERE cm.group_id = NEW.group_id
    AND cm.user_id IS DISTINCT FROM NEW.sender_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_community_message ON public.community_messages;
CREATE TRIGGER trg_notify_community_message
  AFTER INSERT ON public.community_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_community_message_recipients();

CREATE OR REPLACE FUNCTION public.notify_doubt_message_recipients()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sid uuid;
BEGIN
  SELECT t.student_id INTO sid FROM public.doubt_threads t WHERE t.id = NEW.doubt_id;
  IF sid IS NULL THEN
    RETURN NEW;
  END IF;

  -- Staff replied → notify student
  IF NEW.sender_id IS DISTINCT FROM sid THEN
    INSERT INTO public.notifications (user_id, title, body, type, action_route)
    VALUES (
      sid,
      'সন্দেহে নতুন উত্তর',
      COALESCE(NULLIF(trim(NEW.body::text), ''), 'নতুন মেসেজ'),
      'announcement',
      '/student/doubts/' || NEW.doubt_id::text
    );
    RETURN NEW;
  END IF;

  -- Student message → notify admins & teachers (inbox)
  INSERT INTO public.notifications (user_id, title, body, type, action_route)
  SELECT
    u.id,
    'নতুন সন্দেহ মেসেজ',
    COALESCE(NULLIF(trim(NEW.body::text), ''), 'শিক্ষার্থীর মেসেজ'),
    'announcement',
    CASE u.role
      WHEN 'admin' THEN '/admin/doubts/' || NEW.doubt_id::text
      WHEN 'teacher' THEN '/teacher/doubts/' || NEW.doubt_id::text
      ELSE '/admin/doubts/' || NEW.doubt_id::text
    END
  FROM public.users u
  WHERE u.role IN ('admin', 'teacher')
    AND u.id IS DISTINCT FROM NEW.sender_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_doubt_message ON public.doubt_messages;
CREATE TRIGGER trg_notify_doubt_message
  AFTER INSERT ON public.doubt_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_doubt_message_recipients();
