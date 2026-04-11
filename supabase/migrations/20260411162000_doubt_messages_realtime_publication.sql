-- Ensure doubt_messages is included in Supabase realtime publication.
-- Safe on rerun.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'doubt_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.doubt_messages;
  END IF;
END
$$;
