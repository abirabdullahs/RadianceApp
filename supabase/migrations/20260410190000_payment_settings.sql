-- Payment settings (admin configurable defaults)

CREATE TABLE IF NOT EXISTS public.payment_settings (
  singleton_key INT PRIMARY KEY DEFAULT 1 CHECK (singleton_key = 1),
  monthly_default_amount NUMERIC(10,2) NOT NULL DEFAULT 1500,
  admission_default_amount NUMERIC(10,2) NOT NULL DEFAULT 500,
  material_default_amount NUMERIC(10,2) NOT NULL DEFAULT 300,
  exam_default_amount NUMERIC(10,2) NOT NULL DEFAULT 100,
  special_default_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  fine_default_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  due_day_of_month INT NOT NULL DEFAULT 15 CHECK (due_day_of_month BETWEEN 1 AND 31),
  auto_generate_due_day INT NOT NULL DEFAULT 1 CHECK (auto_generate_due_day BETWEEN 1 AND 31),
  accept_cash BOOLEAN NOT NULL DEFAULT true,
  accept_bkash BOOLEAN NOT NULL DEFAULT true,
  accept_nagad BOOLEAN NOT NULL DEFAULT true,
  accept_bank BOOLEAN NOT NULL DEFAULT true,
  accept_other BOOLEAN NOT NULL DEFAULT true,
  bkash_number TEXT,
  nagad_number TEXT,
  bank_details TEXT,
  voucher_center_name TEXT NOT NULL DEFAULT 'Radiance Coaching Center',
  voucher_address TEXT,
  voucher_phone TEXT,
  voucher_qr_enabled BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

INSERT INTO public.payment_settings (singleton_key)
VALUES (1)
ON CONFLICT (singleton_key) DO NOTHING;

ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_settings_select_auth ON public.payment_settings;
CREATE POLICY payment_settings_select_auth
  ON public.payment_settings FOR SELECT
  TO authenticated
  USING (public.is_admin() OR public.is_student());

DROP POLICY IF EXISTS payment_settings_write_admin ON public.payment_settings;
CREATE POLICY payment_settings_write_admin
  ON public.payment_settings FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
