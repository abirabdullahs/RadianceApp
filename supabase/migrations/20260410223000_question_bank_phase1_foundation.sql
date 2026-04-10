-- =============================================
-- QUESTION BANK PHASE 1 (A-Z plan foundation)
-- Session -> Subject -> Chapter -> MCQ/CQ
-- + bookmarks + practice + search RPC + RLS
-- =============================================

-- SESSION
CREATE TABLE IF NOT EXISTS public.qbank_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (name)
);

-- SUBJECT (per session)
CREATE TABLE IF NOT EXISTS public.qbank_subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES public.qbank_sessions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (session_id, name)
);

-- CHAPTER (per subject)
CREATE TABLE IF NOT EXISTS public.qbank_chapters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject_id UUID NOT NULL REFERENCES public.qbank_subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (subject_id, name)
);

-- MCQ QUESTIONS
CREATE TABLE IF NOT EXISTS public.qbank_mcq (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chapter_id UUID NOT NULL REFERENCES public.qbank_chapters(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  image_url TEXT,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option CHAR(1) NOT NULL CHECK (correct_option IN ('A','B','C','D')),
  explanation TEXT,
  explanation_image_url TEXT,
  difficulty VARCHAR(10) NOT NULL DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source VARCHAR(50),
  board_year INT,
  board_name TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}',
  is_published BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CQ QUESTIONS
CREATE TABLE IF NOT EXISTS public.qbank_cq (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chapter_id UUID NOT NULL REFERENCES public.qbank_chapters(id) ON DELETE CASCADE,
  stem_text TEXT NOT NULL,
  stem_image_url TEXT,
  ga_text TEXT NOT NULL,
  ga_image_url TEXT,
  ga_answer TEXT,
  ga_marks INT NOT NULL DEFAULT 3 CHECK (ga_marks > 0),
  gha_text TEXT NOT NULL,
  gha_image_url TEXT,
  gha_answer TEXT,
  gha_marks INT NOT NULL DEFAULT 4 CHECK (gha_marks > 0),
  difficulty VARCHAR(10) NOT NULL DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source VARCHAR(50),
  board_year INT,
  board_name TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}',
  is_published BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- BOOKMARKS
CREATE TABLE IF NOT EXISTS public.qbank_bookmarks_v2 (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  question_type VARCHAR(5) NOT NULL CHECK (question_type IN ('mcq', 'cq')),
  question_id UUID NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (student_id, question_type, question_id)
);

-- PRACTICE SESSIONS
CREATE TABLE IF NOT EXISTS public.qbank_practice_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  chapter_id UUID REFERENCES public.qbank_chapters(id) ON DELETE SET NULL,
  question_type VARCHAR(5) NOT NULL CHECK (question_type IN ('mcq', 'cq', 'mixed')),
  total_questions INT NOT NULL DEFAULT 0,
  correct_answers INT NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.qbank_practice_answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES public.qbank_practice_sessions(id) ON DELETE CASCADE,
  question_id UUID NOT NULL,
  question_type VARCHAR(5) NOT NULL CHECK (question_type IN ('mcq', 'cq')),
  selected_option CHAR(1) CHECK (selected_option IN ('A','B','C','D')),
  is_correct BOOLEAN
);

-- updated_at trigger helper
CREATE OR REPLACE FUNCTION public.set_updated_at_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_qbank_mcq_updated_at ON public.qbank_mcq;
CREATE TRIGGER trg_qbank_mcq_updated_at
BEFORE UPDATE ON public.qbank_mcq
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at_timestamp();

DROP TRIGGER IF EXISTS trg_qbank_cq_updated_at ON public.qbank_cq;
CREATE TRIGGER trg_qbank_cq_updated_at
BEFORE UPDATE ON public.qbank_cq
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at_timestamp();

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_qbank_subjects_session ON public.qbank_subjects(session_id);
CREATE INDEX IF NOT EXISTS idx_qbank_chapters_subject ON public.qbank_chapters(subject_id);
CREATE INDEX IF NOT EXISTS idx_qbank_mcq_chapter ON public.qbank_mcq(chapter_id);
CREATE INDEX IF NOT EXISTS idx_qbank_mcq_filters ON public.qbank_mcq(chapter_id, is_published, difficulty, source, board_year);
CREATE INDEX IF NOT EXISTS idx_qbank_cq_chapter ON public.qbank_cq(chapter_id);
CREATE INDEX IF NOT EXISTS idx_qbank_cq_filters ON public.qbank_cq(chapter_id, is_published, difficulty, source, board_year);
CREATE INDEX IF NOT EXISTS idx_qbank_bookmarks_v2_student ON public.qbank_bookmarks_v2(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_qbank_practice_sessions_student ON public.qbank_practice_sessions(student_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_qbank_practice_answers_session ON public.qbank_practice_answers(session_id);

-- Basic search indexes (FTS)
CREATE INDEX IF NOT EXISTS idx_qbank_mcq_text_fts
  ON public.qbank_mcq
  USING GIN (to_tsvector('simple', coalesce(question_text, '') || ' ' || coalesce(explanation, '')));

CREATE INDEX IF NOT EXISTS idx_qbank_cq_text_fts
  ON public.qbank_cq
  USING GIN (to_tsvector('simple', coalesce(stem_text, '') || ' ' || coalesce(ga_text, '') || ' ' || coalesce(gha_text, '')));

-- Seed core sessions
INSERT INTO public.qbank_sessions (name, name_bn, display_order)
VALUES
  ('SSC', 'এসএসসি', 1),
  ('HSC', 'এইচএসসি', 2)
ON CONFLICT (name) DO NOTHING;

-- Chapter-wise stats view
CREATE OR REPLACE VIEW public.qbank_chapter_stats AS
SELECT
  c.id AS chapter_id,
  c.subject_id,
  COALESCE(mcq.count_mcq, 0) AS mcq_count,
  COALESCE(cq.count_cq, 0) AS cq_count
FROM public.qbank_chapters c
LEFT JOIN (
  SELECT chapter_id, COUNT(*)::INT AS count_mcq
  FROM public.qbank_mcq
  WHERE is_published = true
  GROUP BY chapter_id
) mcq ON mcq.chapter_id = c.id
LEFT JOIN (
  SELECT chapter_id, COUNT(*)::INT AS count_cq
  FROM public.qbank_cq
  WHERE is_published = true
  GROUP BY chapter_id
) cq ON cq.chapter_id = c.id;

-- Global search RPC (MCQ + CQ)
CREATE OR REPLACE FUNCTION public.qbank_search_questions(
  p_query TEXT,
  p_session_id UUID DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_question_type TEXT DEFAULT NULL,
  p_limit INT DEFAULT 30
)
RETURNS TABLE (
  question_type TEXT,
  question_id UUID,
  chapter_id UUID,
  subject_id UUID,
  session_id UUID,
  preview_text TEXT,
  difficulty TEXT,
  source TEXT,
  board_year INT,
  board_name TEXT
)
LANGUAGE sql
STABLE
AS $$
  WITH scope_chapters AS (
    SELECT ch.id AS chapter_id, sb.id AS subject_id, ss.id AS session_id
    FROM public.qbank_chapters ch
    JOIN public.qbank_subjects sb ON sb.id = ch.subject_id
    JOIN public.qbank_sessions ss ON ss.id = sb.session_id
    WHERE (p_session_id IS NULL OR ss.id = p_session_id)
      AND (p_subject_id IS NULL OR sb.id = p_subject_id)
  ),
  q_mcq AS (
    SELECT
      'mcq'::TEXT AS question_type,
      m.id AS question_id,
      m.chapter_id,
      sc.subject_id,
      sc.session_id,
      left(m.question_text, 220) AS preview_text,
      m.difficulty::TEXT,
      m.source::TEXT,
      m.board_year,
      m.board_name::TEXT
    FROM public.qbank_mcq m
    JOIN scope_chapters sc ON sc.chapter_id = m.chapter_id
    WHERE m.is_published = true
      AND (p_question_type IS NULL OR p_question_type = 'mcq')
      AND (
        p_query IS NULL
        OR p_query = ''
        OR m.question_text ILIKE '%' || p_query || '%'
        OR coalesce(m.explanation, '') ILIKE '%' || p_query || '%'
      )
  ),
  q_cq AS (
    SELECT
      'cq'::TEXT AS question_type,
      c.id AS question_id,
      c.chapter_id,
      sc.subject_id,
      sc.session_id,
      left(c.stem_text, 220) AS preview_text,
      c.difficulty::TEXT,
      c.source::TEXT,
      c.board_year,
      c.board_name::TEXT
    FROM public.qbank_cq c
    JOIN scope_chapters sc ON sc.chapter_id = c.chapter_id
    WHERE c.is_published = true
      AND (p_question_type IS NULL OR p_question_type = 'cq')
      AND (
        p_query IS NULL
        OR p_query = ''
        OR c.stem_text ILIKE '%' || p_query || '%'
        OR c.ga_text ILIKE '%' || p_query || '%'
        OR c.gha_text ILIKE '%' || p_query || '%'
      )
  )
  SELECT * FROM q_mcq
  UNION ALL
  SELECT * FROM q_cq
  LIMIT GREATEST(COALESCE(p_limit, 30), 1);
$$;

-- RLS
ALTER TABLE public.qbank_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_mcq ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_cq ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_bookmarks_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_practice_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qbank_practice_answers ENABLE ROW LEVEL SECURITY;

-- Sessions/subjects/chapters: readable by authenticated, writable by admin
CREATE POLICY "qbank_sessions_read_auth" ON public.qbank_sessions FOR SELECT TO authenticated
  USING (is_active = true OR public.is_admin());
CREATE POLICY "qbank_sessions_write_admin" ON public.qbank_sessions FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "qbank_subjects_read_auth" ON public.qbank_subjects FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.qbank_sessions s
      WHERE s.id = qbank_subjects.session_id AND s.is_active = true
    )
  );
CREATE POLICY "qbank_subjects_write_admin" ON public.qbank_subjects FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "qbank_chapters_read_auth" ON public.qbank_chapters FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.qbank_subjects sb
      JOIN public.qbank_sessions ss ON ss.id = sb.session_id
      WHERE sb.id = qbank_chapters.subject_id
        AND sb.is_active = true
        AND ss.is_active = true
    )
  );
CREATE POLICY "qbank_chapters_write_admin" ON public.qbank_chapters FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- MCQ/CQ: students see published only; admin full CRUD
CREATE POLICY "qbank_mcq_read" ON public.qbank_mcq FOR SELECT TO authenticated
  USING (is_published = true OR public.is_admin());
CREATE POLICY "qbank_mcq_write_admin" ON public.qbank_mcq FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "qbank_cq_read" ON public.qbank_cq FOR SELECT TO authenticated
  USING (is_published = true OR public.is_admin());
CREATE POLICY "qbank_cq_write_admin" ON public.qbank_cq FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Bookmarks: own data only, admin can inspect
CREATE POLICY "qbank_bm_v2_select" ON public.qbank_bookmarks_v2 FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR public.is_admin());
CREATE POLICY "qbank_bm_v2_insert" ON public.qbank_bookmarks_v2 FOR INSERT TO authenticated
  WITH CHECK (student_id = auth.uid() OR public.is_admin());
CREATE POLICY "qbank_bm_v2_update" ON public.qbank_bookmarks_v2 FOR UPDATE TO authenticated
  USING (student_id = auth.uid() OR public.is_admin())
  WITH CHECK (student_id = auth.uid() OR public.is_admin());
CREATE POLICY "qbank_bm_v2_delete" ON public.qbank_bookmarks_v2 FOR DELETE TO authenticated
  USING (student_id = auth.uid() OR public.is_admin());

-- Practice sessions/answers: own data only, admin can inspect
CREATE POLICY "qbank_practice_session_select" ON public.qbank_practice_sessions FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR public.is_admin());
CREATE POLICY "qbank_practice_session_insert" ON public.qbank_practice_sessions FOR INSERT TO authenticated
  WITH CHECK (student_id = auth.uid() OR public.is_admin());
CREATE POLICY "qbank_practice_session_update" ON public.qbank_practice_sessions FOR UPDATE TO authenticated
  USING (student_id = auth.uid() OR public.is_admin())
  WITH CHECK (student_id = auth.uid() OR public.is_admin());

CREATE POLICY "qbank_practice_answers_select" ON public.qbank_practice_answers FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.qbank_practice_sessions ps
      WHERE ps.id = qbank_practice_answers.session_id
        AND ps.student_id = auth.uid()
    )
  );
CREATE POLICY "qbank_practice_answers_insert" ON public.qbank_practice_answers FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.qbank_practice_sessions ps
      WHERE ps.id = qbank_practice_answers.session_id
        AND ps.student_id = auth.uid()
    )
  );

GRANT SELECT ON public.qbank_chapter_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.qbank_search_questions(TEXT, UUID, UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qbank_search_questions(TEXT, UUID, UUID, TEXT, INT) TO service_role;
