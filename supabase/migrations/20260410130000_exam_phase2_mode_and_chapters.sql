-- Exam Phase 2: mode + chapter scope
-- online/offline mode and chapter multi-select support.

ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS exam_mode VARCHAR(10) NOT NULL DEFAULT 'online'
  CHECK (exam_mode IN ('online', 'offline'));

ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS chapter_ids UUID[] NOT NULL DEFAULT '{}';
