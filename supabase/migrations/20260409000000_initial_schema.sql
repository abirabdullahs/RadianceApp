-- Radiance initial schema (see plan/03_database_roadmap.md)
-- Run with Supabase CLI or paste in SQL editor.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- USERS
-- =============================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(255),
  full_name_bn TEXT NOT NULL,
  full_name_en TEXT,
  avatar_url TEXT,
  role VARCHAR(10) NOT NULL DEFAULT 'student'
    CHECK (role IN ('admin', 'student')),
  student_id VARCHAR(20) UNIQUE,
  date_of_birth DATE,
  guardian_phone VARCHAR(15),
  address TEXT,
  class_level VARCHAR(20)
    CHECK (class_level IN ('SSC', 'HSC', 'Admission', 'Other')),
  fcm_token TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.generate_student_id()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := EXTRACT(YEAR FROM now())::TEXT;
  next_num INT;
BEGIN
  SELECT COALESCE(MAX(
    CAST(SPLIT_PART(student_id, '-', 3) AS INT)
  ), 0) + 1
  INTO next_num FROM public.users WHERE student_id LIKE 'RCC-' || year_str || '-%';

  NEW.student_id := 'RCC-' || year_str || '-' || LPAD(next_num::TEXT, 3, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_student_id
  BEFORE INSERT ON public.users
  FOR EACH ROW
  WHEN (NEW.role = 'student' AND (NEW.student_id IS NULL OR NEW.student_id = ''))
  EXECUTE FUNCTION public.generate_student_id();

-- =============================================
-- COURSES, SUBJECTS, CHAPTERS
-- =============================================
CREATE TABLE public.courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  thumbnail_url TEXT,
  monthly_fee NUMERIC(10,2) NOT NULL CHECK (monthly_fee >= 0),
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.chapters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- NOTES
-- =============================================
CREATE TABLE public.notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  type VARCHAR(20) NOT NULL
    CHECK (type IN ('pdf', 'text', 'video_youtube', 'video_upload', 'image', 'link')),
  file_url TEXT,
  content TEXT,
  is_published BOOLEAN DEFAULT false,
  view_count INT DEFAULT 0,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- ENROLLMENTS
-- =============================================
CREATE TABLE public.enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  enrolled_at DATE DEFAULT CURRENT_DATE,
  status VARCHAR(20) DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'completed')),
  enrolled_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, course_id)
);

-- =============================================
-- PAYMENTS
-- =============================================
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  voucher_no VARCHAR(30) UNIQUE NOT NULL,
  student_id UUID NOT NULL REFERENCES public.users(id),
  course_id UUID NOT NULL REFERENCES public.courses(id),
  for_month DATE NOT NULL,
  amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  payment_method VARCHAR(20)
    CHECK (payment_method IN ('cash', 'bkash', 'nagad', 'bank', 'other')),
  status VARCHAR(20) DEFAULT 'paid'
    CHECK (status IN ('paid', 'partial')),
  note TEXT,
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES public.users(id)
);

CREATE OR REPLACE FUNCTION public.generate_voucher_no()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := EXTRACT(YEAR FROM now())::TEXT;
  next_num INT;
BEGIN
  SELECT COALESCE(MAX(
    CAST(SPLIT_PART(voucher_no, '-', 4) AS INT)
  ), 0) + 1
  INTO next_num FROM public.payments WHERE voucher_no LIKE 'RCC-VCH-' || year_str || '-%';

  NEW.voucher_no := 'RCC-VCH-' || year_str || '-' || LPAD(next_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_voucher_no
  BEFORE INSERT ON public.payments
  FOR EACH ROW
  WHEN (NEW.voucher_no IS NULL OR NEW.voucher_no = '')
  EXECUTE FUNCTION public.generate_voucher_no();

CREATE TABLE public.payment_dues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id),
  course_id UUID NOT NULL REFERENCES public.courses(id),
  for_month DATE NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  status VARCHAR(20) DEFAULT 'due'
    CHECK (status IN ('due', 'paid', 'partial', 'waived')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, course_id, for_month)
);

-- =============================================
-- ATTENDANCE
-- =============================================
CREATE TABLE public.attendance_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES public.courses(id),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(course_id, date)
);

CREATE TABLE public.attendance_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES public.attendance_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.users(id),
  status VARCHAR(10) NOT NULL DEFAULT 'absent'
    CHECK (status IN ('present', 'absent', 'late')),
  UNIQUE(session_id, student_id)
);

CREATE TABLE public.attendance_edit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  record_id UUID NOT NULL REFERENCES public.attendance_records(id),
  old_status VARCHAR(10),
  new_status VARCHAR(10),
  changed_by UUID REFERENCES public.users(id),
  changed_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- EXAMS & QUESTIONS
-- =============================================
CREATE TABLE public.exams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES public.courses(id),
  subject_id UUID REFERENCES public.subjects(id),
  title TEXT NOT NULL,
  instructions TEXT,
  duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  total_marks NUMERIC(6,2),
  pass_marks NUMERIC(6,2),
  shuffle_questions BOOLEAN DEFAULT false,
  show_result_immediately BOOLEAN DEFAULT true,
  negative_marking NUMERIC(4,2) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'draft'
    CHECK (status IN ('draft', 'scheduled', 'live', 'ended', 'result_published')),
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  image_url TEXT,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option CHAR(1) NOT NULL CHECK (correct_option IN ('A','B','C','D')),
  marks NUMERIC(4,2) DEFAULT 1,
  explanation TEXT,
  display_order INT DEFAULT 0
);

CREATE TABLE public.exam_submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES public.exams(id),
  student_id UUID NOT NULL REFERENCES public.users(id),
  answers JSONB NOT NULL DEFAULT '{}',
  score NUMERIC(6,2),
  total_correct INT DEFAULT 0,
  total_wrong INT DEFAULT 0,
  started_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  is_auto_submitted BOOLEAN DEFAULT false,
  UNIQUE(exam_id, student_id)
);

-- =============================================
-- RESULTS
-- =============================================
CREATE TABLE public.results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES public.exams(id),
  student_id UUID NOT NULL REFERENCES public.users(id),
  score NUMERIC(6,2) NOT NULL,
  total_marks NUMERIC(6,2) NOT NULL,
  percentage NUMERIC(5,2),
  grade VARCHAR(5),
  rank INT,
  is_passed BOOLEAN,
  published_at TIMESTAMPTZ,
  UNIQUE(exam_id, student_id)
);

-- =============================================
-- QUESTION BANK
-- =============================================
CREATE TABLE public.qbank_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID REFERENCES public.courses(id),
  subject_id UUID REFERENCES public.subjects(id),
  chapter_id UUID REFERENCES public.chapters(id),
  question_text TEXT NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('mcq', 'short', 'broad')),
  option_a TEXT,
  option_b TEXT,
  option_c TEXT,
  option_d TEXT,
  correct_option CHAR(1) CHECK (correct_option IN ('A','B','C','D')),
  answer_text TEXT,
  explanation TEXT,
  image_url TEXT,
  difficulty VARCHAR(10) DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source VARCHAR(50),
  board_year INT,
  is_published BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.qbank_bookmarks (
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.qbank_questions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY(student_id, question_id)
);

-- =============================================
-- COMMUNITY
-- =============================================
CREATE TABLE public.community_groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.community_members (
  group_id UUID NOT NULL REFERENCES public.community_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY(group_id, user_id)
);

CREATE TABLE public.community_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id UUID NOT NULL REFERENCES public.community_groups(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id),
  content TEXT,
  type VARCHAR(20) DEFAULT 'text' CHECK (type IN ('text', 'image', 'file')),
  file_url TEXT,
  reply_to UUID REFERENCES public.community_messages(id),
  is_pinned BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- NOTIFICATIONS & SMS
-- =============================================
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(30)
    CHECK (type IN ('exam','result','payment','note','announcement','attendance','complaint')),
  action_route TEXT,
  is_read BOOLEAN DEFAULT false,
  fcm_sent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.sms_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  to_phone VARCHAR(15) NOT NULL,
  message TEXT NOT NULL,
  gateway VARCHAR(30) DEFAULT 'ssl_wireless',
  status VARCHAR(20) DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
  sent_at TIMESTAMPTZ DEFAULT now(),
  response JSONB
);

-- =============================================
-- COMPLAINTS
-- =============================================
CREATE TABLE public.complaints (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_no VARCHAR(20) UNIQUE,
  student_id UUID NOT NULL REFERENCES public.users(id),
  category VARCHAR(30)
    CHECK (category IN ('academic', 'payment', 'technical', 'other')),
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  attachment_url TEXT,
  status VARCHAR(20) DEFAULT 'pending'
    CHECK (status IN ('pending', 'reviewing', 'resolved', 'rejected')),
  admin_reply TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- HOME CMS
-- =============================================
CREATE TABLE public.home_content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type VARCHAR(30) NOT NULL
    CHECK (type IN ('banner', 'notice', 'marketing', 'announcement')),
  title TEXT,
  content JSONB DEFAULT '{}',
  image_url TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- SUGGESTIONS
-- =============================================
CREATE TABLE public.suggestions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  content TEXT,
  type VARCHAR(20) DEFAULT 'tip'
    CHECK (type IN ('tip', 'guide', 'motivation', 'strategy')),
  image_url TEXT,
  video_url TEXT,
  course_id UUID REFERENCES public.courses(id),
  likes_count INT DEFAULT 0,
  is_published BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.suggestion_likes (
  suggestion_id UUID NOT NULL REFERENCES public.suggestions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY(suggestion_id, student_id)
);

-- =============================================
-- RPC: exam ranks
-- =============================================
CREATE OR REPLACE FUNCTION public.calculate_exam_ranks(p_exam_id UUID)
RETURNS VOID
LANGUAGE SQL
AS $$
  UPDATE public.results SET rank = r.rank FROM (
    SELECT id, DENSE_RANK() OVER (ORDER BY score DESC)::INT AS rank
    FROM public.results WHERE exam_id = p_exam_id
  ) r WHERE public.results.id = r.id AND public.results.exam_id = p_exam_id;
$$;
