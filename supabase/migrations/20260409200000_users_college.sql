-- Optional: which school/college the student attends (BD coaching context).
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS college TEXT;

COMMENT ON COLUMN public.users.college IS 'Student school or college name (optional)';
