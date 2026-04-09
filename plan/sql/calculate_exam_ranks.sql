-- Run in Supabase SQL editor or via migration.
-- Assigns DENSE_RANK by score (descending) for all rows in `results` for one exam.

CREATE OR REPLACE FUNCTION calculate_exam_ranks(p_exam_id UUID)
RETURNS VOID AS $$
  UPDATE results SET rank = r.rank FROM (
    SELECT id, DENSE_RANK() OVER (ORDER BY score DESC)::INT AS rank
    FROM results WHERE exam_id = p_exam_id
  ) r WHERE results.id = r.id AND results.exam_id = p_exam_id;
$$ LANGUAGE SQL;
