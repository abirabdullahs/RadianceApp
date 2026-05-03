-- Public voucher lookup for QR verification page.
-- Returns limited receipt data for a given voucher number.

CREATE OR REPLACE FUNCTION public.public_get_voucher_by_no(
  p_voucher_no TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_voucher TEXT := trim(coalesce(p_voucher_no, ''));
  v_rows JSONB := '[]'::jsonb;
BEGIN
  IF v_voucher = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'empty_voucher'
    );
  END IF;

  WITH q AS (
    SELECT
      l.id,
      l.voucher_no,
      l.payment_type_code,
      l.for_month,
      l.amount_due,
      l.amount_paid,
      l.discount_amount,
      l.fine_amount,
      l.paid_at,
      l.student_id,
      l.course_id,
      u.full_name_bn AS student_name,
      u.student_id AS student_code,
      c.name AS course_name
    FROM public.payment_ledger l
    LEFT JOIN public.users u ON u.id = l.student_id
    LEFT JOIN public.courses c ON c.id = l.course_id
    WHERE l.voucher_no = v_voucher
    ORDER BY l.created_at ASC
  )
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'voucher_no', voucher_no,
        'payment_type_code', payment_type_code,
        'for_month', for_month,
        'amount_due', amount_due,
        'amount_paid', amount_paid,
        'discount_amount', discount_amount,
        'fine_amount', fine_amount,
        'paid_at', paid_at,
        'student_id', student_id,
        'student_name', student_name,
        'student_code', student_code,
        'course_id', course_id,
        'course_name', course_name
      )
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM q;

  IF jsonb_array_length(v_rows) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'not_found'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'voucher_no', v_voucher,
    'items', v_rows
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.public_get_voucher_by_no(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.public_get_voucher_by_no(TEXT)
TO anon, authenticated, service_role;
