# 🗄️ Database Schema + Edge Functions + Roadmap
## Radiance Coaching Center App (Flutter + Supabase + Firebase)

---

## 📊 Complete PostgreSQL Schema (Supabase)

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- USERS
-- =============================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(255),
  full_name_bn TEXT NOT NULL,
  full_name_en TEXT,
  avatar_url TEXT,
  role VARCHAR(10) NOT NULL DEFAULT 'student' 
    CHECK (role IN ('admin', 'student')),
  student_id VARCHAR(20) UNIQUE,       -- RCC-2025-001
  date_of_birth DATE,
  guardian_phone VARCHAR(15),
  address TEXT,
  class_level VARCHAR(20)              -- SSC / HSC / Admission
    CHECK (class_level IN ('SSC', 'HSC', 'Admission', 'Other')),
  fcm_token TEXT,                      -- Firebase push token
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-generate student_id trigger
CREATE OR REPLACE FUNCTION generate_student_id()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := EXTRACT(YEAR FROM now())::TEXT;
  next_num INT;
BEGIN
  SELECT COALESCE(MAX(
    CAST(SPLIT_PART(student_id, '-', 3) AS INT)
  ), 0) + 1
  INTO next_num FROM users WHERE student_id LIKE 'RCC-' || year_str || '-%';
  
  NEW.student_id := 'RCC-' || year_str || '-' || LPAD(next_num::TEXT, 3, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_student_id
  BEFORE INSERT ON users
  FOR EACH ROW
  WHEN (NEW.role = 'student' AND NEW.student_id IS NULL)
  EXECUTE FUNCTION generate_student_id();

-- =============================================
-- COURSES, SUBJECTS, CHAPTERS
-- =============================================
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  thumbnail_url TEXT,
  monthly_fee NUMERIC(10,2) NOT NULL CHECK (monthly_fee >= 0),
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE chapters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- STUDY CONTENT / NOTES
-- =============================================
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  type VARCHAR(20) NOT NULL 
    CHECK (type IN ('pdf', 'text', 'video_youtube', 'video_upload', 'image', 'link')),
  file_url TEXT,
  content TEXT,                        -- For text/HTML type
  is_published BOOLEAN DEFAULT false,
  view_count INT DEFAULT 0,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- ENROLLMENTS
-- =============================================
CREATE TABLE enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  enrolled_at DATE DEFAULT CURRENT_DATE,
  status VARCHAR(20) DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'completed')),
  enrolled_by UUID REFERENCES users(id),  -- admin who enrolled
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, course_id)
);

-- =============================================
-- PAYMENTS
-- =============================================
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  voucher_no VARCHAR(30) UNIQUE NOT NULL,   -- RCC-VCH-2025-0001
  student_id UUID NOT NULL REFERENCES users(id),
  course_id UUID NOT NULL REFERENCES courses(id),
  for_month DATE NOT NULL,                  -- First day of month
  amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  payment_method VARCHAR(20)
    CHECK (payment_method IN ('cash', 'bkash', 'nagad', 'bank', 'other')),
  status VARCHAR(20) DEFAULT 'paid'
    CHECK (status IN ('paid', 'partial')),
  note TEXT,
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES users(id)      -- admin
);

-- Auto voucher number trigger
CREATE OR REPLACE FUNCTION generate_voucher_no()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT := EXTRACT(YEAR FROM now())::TEXT;
  next_num INT;
BEGIN
  SELECT COALESCE(MAX(
    CAST(SPLIT_PART(voucher_no, '-', 4) AS INT)
  ), 0) + 1
  INTO next_num FROM payments WHERE voucher_no LIKE 'RCC-VCH-' || year_str || '-%';
  
  NEW.voucher_no := 'RCC-VCH-' || year_str || '-' || LPAD(next_num::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_voucher_no
  BEFORE INSERT ON payments
  FOR EACH ROW
  WHEN (NEW.voucher_no IS NULL OR NEW.voucher_no = '')
  EXECUTE FUNCTION generate_voucher_no();

CREATE TABLE payment_dues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id),
  course_id UUID NOT NULL REFERENCES courses(id),
  for_month DATE NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  status VARCHAR(20) DEFAULT 'due'
    CHECK (status IN ('due', 'paid', 'partial', 'waived')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, course_id, for_month)
);

-- =============================================
-- ATTENDANCE
-- =============================================
CREATE TABLE attendance_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES courses(id),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(course_id, date)
);

CREATE TABLE attendance_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id),
  status VARCHAR(10) NOT NULL DEFAULT 'absent'
    CHECK (status IN ('present', 'absent', 'late')),
  UNIQUE(session_id, student_id)
);

CREATE TABLE attendance_edit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  record_id UUID NOT NULL REFERENCES attendance_records(id),
  old_status VARCHAR(10),
  new_status VARCHAR(10),
  changed_by UUID REFERENCES users(id),
  changed_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- EXAMS & QUESTIONS
-- =============================================
CREATE TABLE exams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES courses(id),
  subject_id UUID REFERENCES subjects(id),
  title TEXT NOT NULL,
  instructions TEXT,
  duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  total_marks NUMERIC(6,2),
  pass_marks NUMERIC(6,2),
  shuffle_questions BOOLEAN DEFAULT false,
  show_result_immediately BOOLEAN DEFAULT true,
  negative_marking NUMERIC(4,2) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'draft'
    CHECK (status IN ('draft', 'scheduled', 'live', 'ended', 'result_published')),
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,     -- Supports LaTeX: $...$
  image_url TEXT,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option CHAR(1) NOT NULL CHECK (correct_option IN ('A','B','C','D')),
  marks NUMERIC(4,2) DEFAULT 1,
  explanation TEXT,
  display_order INT DEFAULT 0
);

CREATE TABLE exam_submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES exams(id),
  student_id UUID NOT NULL REFERENCES users(id),
  answers JSONB NOT NULL DEFAULT '{}', -- {"question_uuid": "A", ...}
  score NUMERIC(6,2),
  total_correct INT DEFAULT 0,
  total_wrong INT DEFAULT 0,
  started_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  is_auto_submitted BOOLEAN DEFAULT false,
  UNIQUE(exam_id, student_id)
);

-- =============================================
-- RESULTS
-- =============================================
CREATE TABLE results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES exams(id),
  student_id UUID NOT NULL REFERENCES users(id),
  score NUMERIC(6,2) NOT NULL,
  total_marks NUMERIC(6,2) NOT NULL,
  percentage NUMERIC(5,2),
  grade VARCHAR(5),
  rank INT,
  is_passed BOOLEAN,
  published_at TIMESTAMPTZ,
  UNIQUE(exam_id, student_id)
);

-- =============================================
-- QUESTION BANK
-- =============================================
CREATE TABLE qbank_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID REFERENCES courses(id),
  subject_id UUID REFERENCES subjects(id),
  chapter_id UUID REFERENCES chapters(id),
  question_text TEXT NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('mcq', 'short', 'broad')),
  option_a TEXT,
  option_b TEXT,
  option_c TEXT,
  option_d TEXT,
  correct_option CHAR(1) CHECK (correct_option IN ('A','B','C','D')),
  answer_text TEXT,                    -- For short/broad
  explanation TEXT,
  image_url TEXT,
  difficulty VARCHAR(10) DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source VARCHAR(50),                  -- 'board_2023', 'admission_dhaka', 'practice'
  board_year INT,
  is_published BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE qbank_bookmarks (
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES qbank_questions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY(student_id, question_id)
);

-- =============================================
-- COMMUNITY / CHAT
-- =============================================
CREATE TABLE community_groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE community_members (
  group_id UUID NOT NULL REFERENCES community_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY(group_id, user_id)
);

CREATE TABLE community_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id UUID NOT NULL REFERENCES community_groups(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id),
  content TEXT,
  type VARCHAR(20) DEFAULT 'text' CHECK (type IN ('text', 'image', 'file')),
  file_url TEXT,
  reply_to UUID REFERENCES community_messages(id),
  is_pinned BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- NOTIFICATIONS
-- =============================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- NULL = all users
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(30)
    CHECK (type IN ('exam','result','payment','note','announcement','attendance','complaint')),
  action_route TEXT,                   -- GoRouter deep link e.g. '/student/exams/uuid'
  is_read BOOLEAN DEFAULT false,
  fcm_sent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE sms_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  to_phone VARCHAR(15) NOT NULL,
  message TEXT NOT NULL,
  gateway VARCHAR(30) DEFAULT 'ssl_wireless',
  status VARCHAR(20) DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
  sent_at TIMESTAMPTZ DEFAULT now(),
  response JSONB
);

-- =============================================
-- COMPLAINTS
-- =============================================
CREATE TABLE complaints (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_no VARCHAR(20) UNIQUE,        -- RCC-TICKET-001
  student_id UUID NOT NULL REFERENCES users(id),
  category VARCHAR(30)
    CHECK (category IN ('academic', 'payment', 'technical', 'other')),
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  attachment_url TEXT,
  status VARCHAR(20) DEFAULT 'pending'
    CHECK (status IN ('pending', 'reviewing', 'resolved', 'rejected')),
  admin_reply TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- HOME PAGE CMS
-- =============================================
CREATE TABLE home_content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type VARCHAR(30) NOT NULL
    CHECK (type IN ('banner', 'notice', 'marketing', 'announcement')),
  title TEXT,
  content JSONB DEFAULT '{}',          -- Flexible: {text, link, cta, etc.}
  image_url TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- SUGGESTIONS
-- =============================================
CREATE TABLE suggestions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  content TEXT,
  type VARCHAR(20) DEFAULT 'tip'
    CHECK (type IN ('tip', 'guide', 'motivation', 'strategy')),
  image_url TEXT,
  video_url TEXT,
  course_id UUID REFERENCES courses(id), -- NULL = all courses
  likes_count INT DEFAULT 0,
  is_published BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE suggestion_likes (
  suggestion_id UUID NOT NULL REFERENCES suggestions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY(suggestion_id, student_id)
);
```

---

## ⚡ Supabase Edge Functions

### 1. `send-notification` (FCM trigger)

```typescript
// supabase/functions/send-notification/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async (req) => {
  const { user_ids, title, body, action_route, type } = await req.json();

  // Get FCM tokens from users table
  const supabase = createClient(/* ... */);
  const { data: users } = await supabase
    .from('users')
    .select('id, fcm_token')
    .in('id', user_ids)
    .not('fcm_token', 'is', null);

  // Send FCM via HTTP v1 API
  const tokens = users.map(u => u.fcm_token).filter(Boolean);
  
  const fcmResponse = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${FCM_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: tokens[0], // or use multicast
          notification: { title, body },
          data: { action_route, type },
          android: {
            notification: { click_action: 'FLUTTER_NOTIFICATION_CLICK' }
          }
        }
      })
    }
  );

  // Save to notifications table
  await supabase.from('notifications').insert(
    user_ids.map(uid => ({ user_id: uid, title, body, type, action_route, fcm_sent: true }))
  );

  return new Response(JSON.stringify({ success: true }), { status: 200 });
});
```

### 2. `generate-monthly-dues` (Cron — 1st of every month)

```typescript
// supabase/functions/generate-monthly-dues/index.ts
// Cron: "0 0 1 * *" (midnight, 1st of every month)

serve(async (req) => {
  const currentMonth = new Date();
  currentMonth.setDate(1);
  currentMonth.setHours(0, 0, 0, 0);

  // Get all active enrollments
  const { data: enrollments } = await supabase
    .from('enrollments')
    .select('student_id, course_id, courses(monthly_fee)')
    .eq('status', 'active');

  // Upsert dues (ignore if already exists)
  const dues = enrollments.map(e => ({
    student_id: e.student_id,
    course_id: e.course_id,
    for_month: currentMonth.toISOString(),
    amount: e.courses.monthly_fee,
    status: 'due'
  }));

  await supabase.from('payment_dues').upsert(dues, { 
    onConflict: 'student_id,course_id,for_month',
    ignoreDuplicates: true 
  });

  // Trigger payment reminder notifications
  // (call send-notification function)

  return new Response(JSON.stringify({ created: dues.length }));
});
```

### 3. `send-sms` (SSL Wireless gateway)

```typescript
// supabase/functions/send-sms/index.ts
serve(async (req) => {
  const { phone, message } = await req.json();

  const response = await fetch('https://ssl.expresssms.net/api/smsapi', {
    method: 'POST',
    body: new URLSearchParams({
      api_token: Deno.env.get('SSL_SMS_API_KEY')!,
      sid: 'RADIANCE',
      msisdn: phone,
      sms: message,
      csms_id: Date.now().toString()
    })
  });

  // Log to sms_logs table
  await supabase.from('sms_logs').insert({
    to_phone: phone,
    message,
    status: response.ok ? 'sent' : 'failed',
    response: await response.json()
  });

  return new Response(JSON.stringify({ success: response.ok }));
});
```

---

## 🔐 Row Level Security (RLS) Policies

```sql
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
-- (repeat for all tables)

-- Users: student sees own row, admin sees all
CREATE POLICY "users_student_own" ON users
  FOR SELECT USING (
    auth.uid() = id OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- Courses: everyone can read active, admin can write
CREATE POLICY "courses_read" ON courses FOR SELECT USING (is_active = true);
CREATE POLICY "courses_admin_write" ON courses FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- Payments: student sees own, admin sees all
CREATE POLICY "payments_student" ON payments
  FOR SELECT USING (
    student_id = auth.uid() OR
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- Attendance: student sees own records
CREATE POLICY "attendance_student" ON attendance_records
  FOR SELECT USING (student_id = auth.uid());

-- Community: member of group can see messages
CREATE POLICY "chat_members_only" ON community_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE group_id = community_messages.group_id
      AND user_id = auth.uid()
    )
  );
```

---

## 🚀 Development Roadmap

### Phase 1 — MVP (10-12 weeks)
```
Week 1-2:
□ Flutter project setup (Expo → Flutter/Dart)
□ Supabase project + schema migration
□ Firebase project + google-services.json
□ Auth: Phone OTP (Supabase)
□ GoRouter setup (admin + student routes)
□ Base theme (colors, fonts, widgets)

Week 3-4:
□ Admin: Course / Subject / Chapter CRUD
□ Admin: Student add + management
□ Supabase Storage: image upload

Week 5-6:
□ Enrollment system
□ Payment management + Due system
□ Voucher PDF generation (pdf dart package)
□ SMS integration (SSL Wireless via Dio)

Week 7-8:
□ Attendance system (roll-call screen)
□ Push notifications (FCM setup)
□ Edge Function: send-notification
□ Edge Function: generate-monthly-dues (cron)

Week 9-10:
□ Exam creation (admin)
□ MCQ exam taking (student)
□ Auto result calculation
□ Result display + PDF

Week 11-12:
□ Notes upload + viewer (PDF/Video/Text)
□ Home page CMS
□ Admin dashboard charts (fl_chart)
□ Bug fixes + beta test

→ Play Store Internal Testing release
```

### Phase 2 (2-3 months after MVP)
```
□ Community group chat (Supabase Realtime)
□ Question bank
□ Student app: full feature polish
□ Complaint system
□ Video content
□ Suggestions
□ Performance analytics
□ Notification settings
```

### Phase 3
```
□ Class timetable / routine
□ Assignment submission
□ Guardian portal (read-only login)
□ Certificate PDF generator
□ Admit card generator
□ Leaderboard
□ Offline mode (Hive sync)
```

---

## 💰 Cost Summary

| Service | Free | Production |
|---|---|---|
| Supabase | 500MB DB, 5GB Storage, 50k auth users | $25/month |
| Firebase FCM | Unlimited | **Free** |
| SSL Wireless SMS | — | ৳0.35/SMS |
| Play Store | $25 one-time | — |
| **শুরুতে মোট** | **Free** | **~৳3,000/month (50+ SMS/day)** |

---

## 📋 Environment Variables

```env
# .env (Flutter — dart-define)
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...

# Supabase Edge Function secrets
SSL_SMS_API_KEY=your_ssl_wireless_key
FCM_PROJECT_ID=radiance-app-xxxx
FCM_SERVICE_ACCOUNT_JSON={"type":"service_account",...}

# Flutter build command:
# flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

---

## 📦 Play Store Checklist

- [ ] App icon: 512×512 PNG (adaptive icon)
- [ ] Feature graphic: 1024×500 PNG
- [ ] Screenshots: minimum 2 phone screenshots
- [ ] Privacy Policy URL (GDPR — student data collect)
- [ ] Content rating: Everyone
- [ ] Target SDK: Android 14 (API 34)
- [ ] Min SDK: Android 8.0 (API 26)
- [ ] Category: Education
- [ ] Bengali + English store description
- [ ] Release notes
- [ ] $25 developer registration (one-time)

---

## 🧪 Useful SQL Queries

```sql
-- এই মাসে কত টাকা collect হয়েছে
SELECT SUM(amount) FROM payments
WHERE DATE_TRUNC('month', paid_at) = DATE_TRUNC('month', now());

-- কোন students-দের এপ্রিলের due আছে
SELECT u.full_name_bn, u.phone, c.name as course, pd.amount
FROM payment_dues pd
JOIN users u ON pd.student_id = u.id
JOIN courses c ON pd.course_id = c.id
WHERE pd.for_month = '2025-04-01' AND pd.status = 'due';

-- একটা course-এর এই মাসের attendance %
SELECT 
  u.full_name_bn,
  COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as present,
  COUNT(*) as total,
  ROUND(COUNT(CASE WHEN ar.status = 'present' THEN 1 END) * 100.0 / COUNT(*), 1) as pct
FROM attendance_records ar
JOIN attendance_sessions ats ON ar.session_id = ats.id
JOIN users u ON ar.student_id = u.id
WHERE ats.course_id = 'course-uuid'
  AND DATE_TRUNC('month', ats.date) = DATE_TRUNC('month', now())
GROUP BY u.id, u.full_name_bn
ORDER BY pct ASC;

-- একটা exam-এর result calculate করে insert
INSERT INTO results (exam_id, student_id, score, total_marks, percentage, grade, is_passed)
SELECT 
  es.exam_id,
  es.student_id,
  es.score,
  e.total_marks,
  ROUND(es.score * 100 / e.total_marks, 2) as percentage,
  CASE 
    WHEN es.score * 100 / e.total_marks >= 90 THEN 'A+'
    WHEN es.score * 100 / e.total_marks >= 80 THEN 'A'
    WHEN es.score * 100 / e.total_marks >= 70 THEN 'A-'
    WHEN es.score * 100 / e.total_marks >= 60 THEN 'B'
    WHEN es.score * 100 / e.total_marks >= 50 THEN 'C'
    WHEN es.score * 100 / e.total_marks >= 40 THEN 'D'
    ELSE 'F'
  END as grade,
  es.score >= e.pass_marks as is_passed
FROM exam_submissions es
JOIN exams e ON es.exam_id = e.id
WHERE es.exam_id = 'exam-uuid';
```
