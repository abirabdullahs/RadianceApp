-- Payment management phase-1 foundation (non-breaking, additive).
-- Keeps existing `payments` / `payment_dues` tables intact while introducing
-- full ledger + schedule + discount + advance structures for gradual rollout.

CREATE TABLE IF NOT EXISTS public.payment_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  code VARCHAR(30) NOT NULL UNIQUE,
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  default_amount NUMERIC(10,2),
  is_active BOOLEAN NOT NULL DEFAULT true,
  color_hex VARCHAR(7) NOT NULL DEFAULT '#1A3C6E',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.payment_types (name, name_bn, code, is_recurring, default_amount, color_hex)
VALUES
  ('Admission Fee', 'ভর্তি ফি', 'admission', false, 500.00, '#9B59B6'),
  ('Monthly Fee', 'মাসিক বেতন', 'monthly', true, 1500.00, '#1A3C6E'),
  ('Material Fee', 'উপকরণ ফি', 'material', false, 300.00, '#27AE60'),
  ('Exam Fee', 'পরীক্ষা ফি', 'exam', false, 100.00, '#E67E22'),
  ('Special Fee', 'বিশেষ ফি', 'special', false, 0.00, '#3498DB'),
  ('Fine', 'জরিমানা', 'fine', false, 0.00, '#E74C3C')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  name_bn = EXCLUDED.name_bn,
  is_recurring = EXCLUDED.is_recurring,
  default_amount = EXCLUDED.default_amount,
  color_hex = EXCLUDED.color_hex,
  is_active = true;

CREATE TABLE IF NOT EXISTS public.payment_ledger (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  voucher_no VARCHAR(40) NOT NULL UNIQUE,
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE RESTRICT,
  payment_type_id UUID NOT NULL REFERENCES public.payment_types(id) ON DELETE RESTRICT,
  payment_type_code VARCHAR(30) NOT NULL,
  for_month DATE,
  amount_due NUMERIC(10,2) NOT NULL CHECK (amount_due >= 0),
  amount_paid NUMERIC(10,2) NOT NULL CHECK (amount_paid >= 0),
  discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  fine_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (fine_amount >= 0),
  payment_method VARCHAR(20) NOT NULL
    CHECK (payment_method IN ('cash','bkash','nagad','rocket','bank','other')),
  transaction_ref VARCHAR(100),
  status VARCHAR(20) NOT NULL DEFAULT 'paid'
    CHECK (status IN ('paid','partial','advance','waived')),
  note TEXT,
  description TEXT,
  paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_ledger_student_paid_idx
  ON public.payment_ledger (student_id, paid_at DESC);
CREATE INDEX IF NOT EXISTS payment_ledger_course_paid_idx
  ON public.payment_ledger (course_id, paid_at DESC);
CREATE INDEX IF NOT EXISTS payment_ledger_for_month_idx
  ON public.payment_ledger (for_month);
CREATE INDEX IF NOT EXISTS payment_ledger_type_idx
  ON public.payment_ledger (payment_type_code);

CREATE TABLE IF NOT EXISTS public.payment_schedule (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  payment_type_id UUID NOT NULL REFERENCES public.payment_types(id) ON DELETE RESTRICT,
  payment_type_code VARCHAR(30) NOT NULL,
  for_month DATE,
  due_date DATE NOT NULL,
  amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','paid','partial','overdue','waived')),
  paid_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  remaining_amount NUMERIC(10,2) GENERATED ALWAYS AS (GREATEST(amount - paid_amount, 0)) STORED,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payment_schedule_unique_target
    UNIQUE (student_id, course_id, payment_type_id, for_month)
);

CREATE INDEX IF NOT EXISTS payment_schedule_status_due_idx
  ON public.payment_schedule (status, due_date);
CREATE INDEX IF NOT EXISTS payment_schedule_student_idx
  ON public.payment_schedule (student_id, for_month DESC);

CREATE TABLE IF NOT EXISTS public.discount_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  discount_type VARCHAR(20) NOT NULL DEFAULT 'percentage'
    CHECK (discount_type IN ('percentage','fixed')),
  discount_value NUMERIC(8,2) NOT NULL CHECK (discount_value >= 0),
  applies_to VARCHAR(30) NOT NULL DEFAULT 'monthly',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.student_discounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  discount_rule_id UUID REFERENCES public.discount_rules(id) ON DELETE SET NULL,
  custom_amount NUMERIC(10,2) CHECK (custom_amount >= 0),
  custom_reason TEXT,
  applies_to VARCHAR(30) NOT NULL DEFAULT 'monthly',
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_until DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS student_discounts_student_idx
  ON public.student_discounts (student_id, course_id, valid_from DESC);

CREATE TABLE IF NOT EXISTS public.advance_balance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  balance NUMERIC(10,2) NOT NULL DEFAULT 0,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (student_id, course_id)
);

CREATE TABLE IF NOT EXISTS public.payment_voucher_seq (
  year INT PRIMARY KEY,
  last_seq INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.next_payment_voucher_no()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  yr INT := EXTRACT(YEAR FROM now())::INT;
  next_seq INT;
BEGIN
  INSERT INTO public.payment_voucher_seq (year, last_seq)
  VALUES (yr, 0)
  ON CONFLICT (year) DO NOTHING;

  UPDATE public.payment_voucher_seq
  SET last_seq = last_seq + 1,
      updated_at = now()
  WHERE year = yr
  RETURNING last_seq INTO next_seq;

  RETURN 'RCC-' || yr::TEXT || '-' || LPAD(next_seq::TEXT, 4, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_set_payment_ledger_voucher_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.voucher_no IS NULL OR btrim(NEW.voucher_no) = '' THEN
    NEW.voucher_no := public.next_payment_voucher_no();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_payment_ledger_voucher_no ON public.payment_ledger;
CREATE TRIGGER set_payment_ledger_voucher_no
  BEFORE INSERT ON public.payment_ledger
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_set_payment_ledger_voucher_no();

CREATE OR REPLACE FUNCTION public.trg_set_payment_schedule_overdue()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  IF NEW.status IN ('pending', 'partial') AND NEW.due_date < CURRENT_DATE THEN
    NEW.status := 'overdue';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_payment_schedule_overdue ON public.payment_schedule;
CREATE TRIGGER set_payment_schedule_overdue
  BEFORE INSERT OR UPDATE ON public.payment_schedule
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_set_payment_schedule_overdue();

ALTER TABLE public.payment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advance_balance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_voucher_seq ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_types_select_auth ON public.payment_types;
CREATE POLICY payment_types_select_auth
  ON public.payment_types FOR SELECT
  TO authenticated
  USING (public.is_admin() OR is_active = true);

DROP POLICY IF EXISTS payment_types_write_admin ON public.payment_types;
CREATE POLICY payment_types_write_admin
  ON public.payment_types FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS payment_ledger_select ON public.payment_ledger;
CREATE POLICY payment_ledger_select
  ON public.payment_ledger FOR SELECT
  TO authenticated
  USING (public.is_admin() OR student_id = auth.uid());

DROP POLICY IF EXISTS payment_ledger_write_admin ON public.payment_ledger;
CREATE POLICY payment_ledger_write_admin
  ON public.payment_ledger FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS payment_schedule_select ON public.payment_schedule;
CREATE POLICY payment_schedule_select
  ON public.payment_schedule FOR SELECT
  TO authenticated
  USING (public.is_admin() OR student_id = auth.uid());

DROP POLICY IF EXISTS payment_schedule_write_admin ON public.payment_schedule;
CREATE POLICY payment_schedule_write_admin
  ON public.payment_schedule FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS discount_rules_select_auth ON public.discount_rules;
CREATE POLICY discount_rules_select_auth
  ON public.discount_rules FOR SELECT
  TO authenticated
  USING (public.is_admin() OR is_active = true);

DROP POLICY IF EXISTS discount_rules_write_admin ON public.discount_rules;
CREATE POLICY discount_rules_write_admin
  ON public.discount_rules FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS student_discounts_select ON public.student_discounts;
CREATE POLICY student_discounts_select
  ON public.student_discounts FOR SELECT
  TO authenticated
  USING (public.is_admin() OR student_id = auth.uid());

DROP POLICY IF EXISTS student_discounts_write_admin ON public.student_discounts;
CREATE POLICY student_discounts_write_admin
  ON public.student_discounts FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS advance_balance_select ON public.advance_balance;
CREATE POLICY advance_balance_select
  ON public.advance_balance FOR SELECT
  TO authenticated
  USING (public.is_admin() OR student_id = auth.uid());

DROP POLICY IF EXISTS advance_balance_write_admin ON public.advance_balance;
CREATE POLICY advance_balance_write_admin
  ON public.advance_balance FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS payment_voucher_seq_admin_only ON public.payment_voucher_seq;
CREATE POLICY payment_voucher_seq_admin_only
  ON public.payment_voucher_seq FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

GRANT EXECUTE ON FUNCTION public.next_payment_voucher_no() TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_payment_voucher_no() TO service_role;
