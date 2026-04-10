-- Automatic push dispatch cron (S3.5 extension)
-- Calls Edge Function `send-notification` in queued mode.

CREATE TABLE IF NOT EXISTS public.system_cron_settings (
  singleton_key INTEGER PRIMARY KEY DEFAULT 1 CHECK (singleton_key = 1),
  push_dispatch_url TEXT,
  push_dispatch_secret TEXT,
  push_dispatch_enabled BOOLEAN NOT NULL DEFAULT false,
  updated_by UUID REFERENCES public.users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.system_cron_settings (singleton_key)
VALUES (1)
ON CONFLICT (singleton_key) DO NOTHING;

ALTER TABLE public.system_cron_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS system_cron_settings_select_admin ON public.system_cron_settings;
CREATE POLICY system_cron_settings_select_admin
ON public.system_cron_settings
FOR SELECT
USING (public.is_admin());

DROP POLICY IF EXISTS system_cron_settings_write_admin ON public.system_cron_settings;
CREATE POLICY system_cron_settings_write_admin
ON public.system_cron_settings
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.run_push_dispatch_batch()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url TEXT;
  v_secret TEXT;
  v_enabled BOOLEAN := false;
  v_req_id BIGINT;
BEGIN
  SELECT
    push_dispatch_url,
    push_dispatch_secret,
    push_dispatch_enabled
  INTO v_url, v_secret, v_enabled
  FROM public.system_cron_settings
  WHERE singleton_key = 1;

  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('success', false, 'skipped', 'disabled');
  END IF;

  IF v_url IS NULL OR length(trim(v_url)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'skipped', 'missing_push_dispatch_url');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RETURN jsonb_build_object('success', false, 'skipped', 'pg_net_not_available');
  END IF;

  SELECT net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-cron-secret', COALESCE(v_secret, '')
    ),
    body := jsonb_build_object('mode', 'queued', 'limit', 400)
  )
  INTO v_req_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_req_id,
    'target', v_url
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_push_dispatch_batch() TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_push_dispatch_batch() TO service_role;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available, skipping push dispatch cron setup: %', SQLERRM;
END $$;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_net not available, push dispatch http cron calls disabled: %', SQLERRM;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      PERFORM cron.unschedule('push_dispatch_every_10m_job');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    -- Every 10 minutes: dispatch queued notifications to FCM.
    PERFORM cron.schedule(
      'push_dispatch_every_10m_job',
      '*/10 * * * *',
      $cron$SELECT public.run_push_dispatch_batch();$cron$
    );
  END IF;
END $$;
