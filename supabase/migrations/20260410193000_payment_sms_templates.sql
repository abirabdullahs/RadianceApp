-- SMS templates for payment and due reminders

CREATE TABLE IF NOT EXISTS public.sms_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  template_key VARCHAR(50) NOT NULL UNIQUE,
  name TEXT NOT NULL,
  body TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

INSERT INTO public.sms_templates (template_key, name, body, is_active)
VALUES
  (
    'payment_confirmation',
    'Payment confirmation',
    'প্রিয় {name}, {month} মাসের {type} ৳{amount} পরিশোধিত হয়েছে। ভাউচার: {voucher_no}। ধন্যবাদ — Radiance',
    true
  ),
  (
    'due_reminder',
    'Due reminder',
    'প্রিয় {name}, {month} মাসের {type} ৳{amount} এখনও বকেয়া আছে। দ্রুত পরিশোধ করুন। — Radiance Coaching Center',
    true
  )
ON CONFLICT (template_key) DO NOTHING;

ALTER TABLE public.sms_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sms_templates_select_auth ON public.sms_templates;
CREATE POLICY sms_templates_select_auth
  ON public.sms_templates FOR SELECT
  TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS sms_templates_write_admin ON public.sms_templates;
CREATE POLICY sms_templates_write_admin
  ON public.sms_templates FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
