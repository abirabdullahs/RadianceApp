-- Public read-only class note access by opaque token (no login).
-- Admin/student flows unchanged; each note gets a unique share token.

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS public_share_token TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_public_share_token
  ON public.notes (public_share_token)
  WHERE public_share_token IS NOT NULL;

-- One-time backfill for existing rows
UPDATE public.notes
SET public_share_token = replace(gen_random_uuid()::text, '-', '')
WHERE public_share_token IS NULL;

CREATE OR REPLACE FUNCTION public.notes_set_public_share_token()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $fn$
BEGIN
  IF NEW.public_share_token IS NULL OR btrim(NEW.public_share_token) = '' THEN
    NEW.public_share_token := replace(gen_random_uuid()::text, '-', '');
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_notes_public_share_token ON public.notes;
CREATE TRIGGER trg_notes_public_share_token
  BEFORE INSERT ON public.notes
  FOR EACH ROW
  EXECUTE FUNCTION public.notes_set_public_share_token();

CREATE OR REPLACE FUNCTION public.public_note_by_share_token(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_t TEXT := trim(coalesce(p_token, ''));
  r RECORD;
BEGIN
  IF length(v_t) < 8 THEN
    RETURN jsonb_build_object('success', false, 'message', 'invalid_token');
  END IF;

  SELECT
    n.id,
    n.title,
    n.description,
    n.type,
    n.file_url,
    n.youtube_url,
    n.external_url,
    n.text_content,
    n.content,
    n.thumbnail_url,
    n.is_published
  INTO r
  FROM public.notes n
  WHERE n.public_share_token = v_t;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'not_found');
  END IF;

  IF r.is_published IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'message', 'unpublished');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'note', jsonb_build_object(
      'id', r.id,
      'title', r.title,
      'description', r.description,
      'type', r.type,
      'file_url', r.file_url,
      'youtube_url', r.youtube_url,
      'external_url', r.external_url,
      'text_content', r.text_content,
      'content', r.content,
      'thumbnail_url', r.thumbnail_url
    )
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.public_note_by_share_token(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.public_note_by_share_token(TEXT)
TO anon, authenticated, service_role;
