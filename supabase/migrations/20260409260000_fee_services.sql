-- Fee catalog for payments (dropdown + admin "add new").
-- Payments gain subtotal, discount, optional fee_service_id; amount remains grand total.

CREATE TABLE public.fee_services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fee_services_name_unique UNIQUE (name)
);

CREATE INDEX fee_services_sort_idx ON public.fee_services (sort_order, name);

ALTER TABLE public.payments
  ADD COLUMN fee_service_id UUID REFERENCES public.fee_services(id) ON DELETE SET NULL,
  ADD COLUMN subtotal NUMERIC(10,2),
  ADD COLUMN discount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (discount >= 0);

COMMENT ON COLUMN public.payments.subtotal IS 'Before discount; amount = grand total = subtotal - discount';
COMMENT ON COLUMN public.payments.discount IS 'Taka discounted from subtotal';

-- Backfill legacy rows
UPDATE public.payments
SET subtotal = amount
WHERE subtotal IS NULL;

ALTER TABLE public.payments
  ALTER COLUMN subtotal SET NOT NULL,
  ADD CONSTRAINT payments_subtotal_positive CHECK (subtotal > 0);

-- Grand total = subtotal - discount (enforced in app; avoid float mismatch in CHECK)

INSERT INTO public.fee_services (name, sort_order) VALUES
  ('মাসিক ফি', 10),
  ('ভর্তি ফি', 20),
  ('মডেল টেস্ট / পরীক্ষা', 30),
  ('বই / ম্যাটেরিয়াল', 40),
  ('অন্যান্য', 90)
ON CONFLICT (name) DO NOTHING;

-- RLS: admin only (same pattern as small lookup tables)
ALTER TABLE public.fee_services ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fee_services_select_admin"
  ON public.fee_services FOR SELECT
  USING (public.is_admin());

CREATE POLICY "fee_services_write_admin"
  ON public.fee_services FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "fee_services_update_admin"
  ON public.fee_services FOR UPDATE
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "fee_services_delete_admin"
  ON public.fee_services FOR DELETE
  USING (public.is_admin());
