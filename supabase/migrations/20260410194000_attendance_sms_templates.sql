-- Attendance notification SMS templates

INSERT INTO public.sms_templates (template_key, name, body, is_active)
VALUES
  (
    'attendance_warning_guardian',
    'Attendance warning (guardian)',
    'প্রিয় অভিভাবক, {name} এর উপস্থিতি {month} মাসে {percentage}% (সতর্কতা সীমা {threshold}%)। অনুগ্রহ করে নিয়মিত ক্লাসে উপস্থিতি নিশ্চিত করুন। — Radiance Coaching Center',
    true
  ),
  (
    'attendance_weekly_guardian',
    'Attendance weekly summary (guardian)',
    'প্রিয় অভিভাবক, {name} এর সাপ্তাহিক উপস্থিতি {percentage}%। বিস্তারিত জানতে প্রতিষ্ঠানের সাথে যোগাযোগ করুন। — Radiance Coaching Center',
    false
  )
ON CONFLICT (template_key) DO NOTHING;
