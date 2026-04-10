-- RPC: generate monthly dues into payment_schedule from active enrollments.

CREATE OR REPLACE FUNCTION public.generate_monthly_dues(
  p_month DATE DEFAULT NULL,
  p_course_id UUID DEFAULT NULL,
  p_force BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month DATE := DATE_TRUNC('month', COALESCE(p_month, CURRENT_DATE))::DATE;
  v_due_day INT := 15;
  v_last_day INT := EXTRACT(DAY FROM (DATE_TRUNC('month', v_month) + INTERVAL '1 month - 1 day'))::INT;
  v_due_date DATE;
  v_payment_type_id UUID;
  v_affected INT := 0;
BEGIN
  SELECT COALESCE(ps.due_day_of_month, 15)
  INTO v_due_day
  FROM public.payment_settings ps
  WHERE ps.singleton_key = 1;

  v_due_date := MAKE_DATE(
    EXTRACT(YEAR FROM v_month)::INT,
    EXTRACT(MONTH FROM v_month)::INT,
    LEAST(GREATEST(v_due_day, 1), v_last_day)
  );

  SELECT id
  INTO v_payment_type_id
  FROM public.payment_types
  WHERE code = 'monthly'
  LIMIT 1;

  IF v_payment_type_id IS NULL THEN
    RAISE EXCEPTION 'payment_types.monthly not found';
  END IF;

  INSERT INTO public.payment_schedule (
    student_id,
    course_id,
    payment_type_id,
    payment_type_code,
    for_month,
    due_date,
    amount,
    status,
    paid_amount,
    note,
    created_at,
    updated_at
  )
  SELECT
    e.student_id,
    e.course_id,
    v_payment_type_id,
    'monthly',
    v_month,
    v_due_date,
    GREATEST(base_amount - discount_amount, 0),
    'pending',
    0,
    NULL,
    now(),
    now()
  FROM (
    SELECT
      e.student_id,
      e.course_id,
      c.monthly_fee::NUMERIC(10,2) AS base_amount,
      COALESCE(
        CASE
          WHEN sd.custom_amount IS NOT NULL THEN LEAST(sd.custom_amount, c.monthly_fee)
          WHEN dr.discount_type = 'fixed' THEN LEAST(dr.discount_value, c.monthly_fee)
          WHEN dr.discount_type = 'percentage' THEN LEAST(ROUND((c.monthly_fee * dr.discount_value) / 100.0, 2), c.monthly_fee)
          ELSE 0
        END,
        0
      )::NUMERIC(10,2) AS discount_amount
    FROM public.enrollments e
    JOIN public.courses c ON c.id = e.course_id
    LEFT JOIN LATERAL (
      SELECT *
      FROM public.student_discounts sd0
      WHERE sd0.student_id = e.student_id
        AND sd0.course_id = e.course_id
        AND sd0.is_active = true
        AND COALESCE(sd0.applies_to, 'monthly') = 'monthly'
        AND sd0.valid_from <= v_month
        AND (sd0.valid_until IS NULL OR sd0.valid_until >= v_month)
      ORDER BY sd0.created_at DESC
      LIMIT 1
    ) sd ON true
    LEFT JOIN public.discount_rules dr ON dr.id = sd.discount_rule_id AND dr.is_active = true
    WHERE e.status = 'active'
      AND (p_course_id IS NULL OR e.course_id = p_course_id)
  ) src
  ON CONFLICT (student_id, course_id, payment_type_id, for_month)
  DO UPDATE SET
    due_date = EXCLUDED.due_date,
    amount = EXCLUDED.amount,
    payment_type_code = EXCLUDED.payment_type_code,
    updated_at = now()
  WHERE p_force = true
    AND public.payment_schedule.paid_amount = 0
    AND public.payment_schedule.status IN ('pending', 'partial', 'overdue');

  GET DIAGNOSTICS v_affected = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'month', v_month,
    'due_date', v_due_date,
    'affected', v_affected,
    'forced', p_force
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_monthly_dues(DATE, UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_monthly_dues(DATE, UUID, BOOLEAN) TO service_role;
