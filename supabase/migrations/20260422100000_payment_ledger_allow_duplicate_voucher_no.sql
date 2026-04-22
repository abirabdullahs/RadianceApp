-- Allow grouped multi-line payments under the same voucher number.
-- Previous schema enforced voucher_no UNIQUE, which blocked multi-row vouchers.

BEGIN;

ALTER TABLE public.payment_ledger
  DROP CONSTRAINT IF EXISTS payment_ledger_voucher_no_key;

-- Keep a non-unique lookup index for voucher-based queries in admin/payment UI.
CREATE INDEX IF NOT EXISTS payment_ledger_voucher_no_idx
  ON public.payment_ledger (voucher_no);

COMMIT;
