# 📝 EXAM SYSTEM — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)
### Online MCQ + Offline Physical Exam

---

# 🗄️ DATABASE SCHEMA

```sql
-- =============================================
-- EXAMS (Online MCQ + Offline Physical)
-- =============================================
CREATE TABLE exams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES courses(id),
  subject_id UUID REFERENCES subjects(id),
  title TEXT NOT NULL,
  description TEXT,

  -- Type
  exam_type VARCHAR(10) NOT NULL DEFAULT 'online'
    CHECK (exam_type IN ('online', 'offline')),

  -- Schedule
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  exam_date DATE,               -- Offline exam-এর জন্য
  venue TEXT,                   -- Offline: "Classroom 1"

  -- Online MCQ config (NULL for offline)
  duration_minutes INT,
  total_marks NUMERIC(6,2),
  pass_marks NUMERIC(6,2),
  negative_marking NUMERIC(4,2) DEFAULT 0,
  marks_per_question NUMERIC(4,2) DEFAULT 1,
  shuffle_questions BOOLEAN DEFAULT false,
  show_result_immediately BOOLEAN DEFAULT true,

  status VARCHAR(20) DEFAULT 'draft'
    CHECK (status IN ('draft','scheduled','live','ended','result_published')),

  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- ONLINE: Questions
-- =============================================
CREATE TABLE exam_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
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

-- =============================================
-- ONLINE: Submissions
-- =============================================
CREATE TABLE exam_submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES exams(id),
  student_id UUID NOT NULL REFERENCES users(id),
  answers JSONB NOT NULL DEFAULT '{}',
  score NUMERIC(6,2),
  total_correct INT DEFAULT 0,
  total_wrong INT DEFAULT 0,
  total_skipped INT DEFAULT 0,
  started_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ,
  is_auto_submitted BOOLEAN DEFAULT false,
  UNIQUE(exam_id, student_id)
);

-- =============================================
-- RESULTS (Online + Offline — unified)
-- =============================================
CREATE TABLE results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID NOT NULL REFERENCES exams(id),
  student_id UUID NOT NULL REFERENCES users(id),
  exam_type VARCHAR(10),          -- 'online' | 'offline' (denormalized)

  score NUMERIC(6,2) NOT NULL,
  total_marks NUMERIC(6,2) NOT NULL,
  percentage NUMERIC(5,2),
  total_correct INT,              -- Online only
  total_wrong INT,                -- Online only
  total_skipped INT,              -- Online only
  negative_deduction NUMERIC(6,2) DEFAULT 0,

  grade VARCHAR(5),
  grade_point NUMERIC(3,1),
  rank INT,
  is_passed BOOLEAN,
  time_taken_seconds INT,         -- Online only

  remarks TEXT,                   -- Offline: teacher comment

  is_published BOOLEAN DEFAULT false,
  published_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id),

  UNIQUE(exam_id, student_id)
);
```

---

# 👨‍💼 ADMIN SIDE

## A1. Exam List

```
📝 পরীক্ষা ব্যবস্থাপনা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tabs: [সব] [🌐 Online MCQ] [📋 Offline] [Live 🔴]

┌──────────────────────────────────────────┐
│ 🔴 LIVE  🌐  Chemistry MCQ — CH5         │
│ HSC Biology  |  ⏱ ১৮ মিনিট বাকি         │
│ ২৩ জন চলছে  |  ৫ জন submit করেছে        │
│ [📊 Monitor]  [⏹ Force End]             │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│ 📅 SCHEDULED  📋  Chemistry CQ — April   │
│ ১৫ এপ্রিল ২০২৫  |  Classroom 1          │
│ Result: এখনো দেওয়া হয়নি                 │
│ [✏️ Edit]  [📊 Result দিন]  [🗑️ Delete] │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│ ✅ ENDED  🌐  Physics MCQ — CH3           │
│ Result: Published  |  🏆 Leaderboard আছে │
│ [📊 Result]  [🏆 Leaderboard]           │
└──────────────────────────────────────────┘

[➕ Online MCQ তৈরি করুন]  [➕ Offline পরীক্ষা যোগ করুন]
```

---

## A2. Create Online MCQ (same as before)

```
নতুন Online MCQ পরীক্ষা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

কোর্স:        [HSC Biology Batch ▼]
বিষয়:         [রসায়ন ▼]
শিরোনাম:      [Chemistry MCQ — Chapter 5  ]
বিবরণ:        [মোলের ধারণা ও বিক্রিয়া... ]

শুরু:  [📅 ১০/০৪/২০২৫  🕒 ৩:০০ PM]
শেষ:   [📅 ১০/০৪/২০২৫  🕒 ৪:০০ PM]
সময়কাল: ৩০ মিনিট

পূর্ণমান: [৩০]  পাস নম্বর: [১২]
নেগেটিভ:  [০.২৫]  (0 = নেই)

[✅] প্রশ্ন shuffle করুন
[✅] সাথে সাথে result দেখাও

[পরবর্তী: প্রশ্ন যোগ করুন ▶]
```

*(Question add + Q-Bank import — আগের মতোই)*

---

## A3. ➕ Create Offline Exam (নতুন)

```
নতুন Offline পরীক্ষা যোগ করুন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

কোর্স:    [HSC Biology Batch ▼]
বিষয়:     [রসায়ন ▼]

শিরোনাম:
┌──────────────────────────────────────┐
│ Chemistry CQ — April 2025            │
└──────────────────────────────────────┘

বিবরণ:
┌──────────────────────────────────────┐
│ অধ্যায় ৩-৫ থেকে সৃজনশীল প্রশ্ন।    │
│ ৪টি CQ, যেকোনো ৩টি দিতে হবে।        │
└──────────────────────────────────────┘

পরীক্ষার তারিখ:  [📅 ১৫/০৪/২০২৫]
সময়:            [🕒 ১০:০০ AM — ১২:০০ PM]
স্থান:           [Classroom 1            ]

[📢 Publish + Students Notify করুন]
[💾 Draft হিসেবে রাখুন]
```

**Publish হলে:**
- Enrolled students-এর কাছে push notification + SMS:
  *"📋 নতুন পরীক্ষা: Chemistry CQ — ১৫ এপ্রিল, সকাল ১০টা, Classroom 1"*

---

## A4. 📊 Offline Exam Result Entry (নতুন)

Offline পরীক্ষার পর admin এই screen থেকে result দেবে।

```
📊 Offline Result Upload
Chemistry CQ — April 2025
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1 — পূর্ণমান সেট করুন:

পূর্ণমান:   [৫০]
পাস নম্বর:  [২০]

Step 2 — শিক্ষার্থীদের নম্বর দিন:

🔍 [নাম / আইডি খুঁজুন]

┌───────────────────────────────────────────────┐
│ নাম              | নম্বর      | Grade | Status │
├───────────────────────────────────────────────┤
│ রহিম উদ্দিন      │ [৩৮    ]  │ A-   │ ✅ পাস │
│ সাদিয়া ইসলাম    │ [৪৫    ]  │ A+   │ ✅ পাস │
│ তানভীর হোসেন     │ [৪০    ]  │ A    │ ✅ পাস │
│ করিম মিয়া        │ [১৮    ]  │ F    │ ❌ ফেল │
│ নাজমা বেগম       │ [   ]     │  —   │ —      │
│ রাফি আহমেদ       │ [absent]  │  —   │ ⚪ ABS │
└───────────────────────────────────────────────┘

[absent] টাইপ করলে = পরীক্ষায় ছিল না

মন্তব্য (সবার জন্য optional):
[অধ্যায় ৫ আরও ভালো করতে হবে।]

পাস নম্বর: ২০ → grade auto-assign হচ্ছে

[✅ Save করুন]  [✅ Save + Publish করুন]
```

**Grade auto-assign logic (score field থেকে focus সরলেই):**
```
≥90% → A+   ≥80% → A   ≥70% → A-
≥60% → B    ≥50% → C   ≥40% → D   <40% → F
absent → not graded
```

**Publish হলে:**
- সব participants-এর কাছে notification:
  *"Chemistry CQ-এর ফলাফল প্রকাশিত। Score: ৩৮/৫০ (A-)"*

---

## A5. 🏆 Leaderboard (Online + Offline)

যেকোনো exam-এর result screen থেকে:

```
🏆 Leaderboard
Chemistry MCQ — Chapter 5
HSC Biology Batch
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                [🌐 Online MCQ]

🥇  সাদিয়া ইসলাম      ২৯/৩০  (97%)  A+
🥈  রহিম উদ্দিন        ২৭/৩০  (90%)  A+
🥉  তানভীর হোসেন       ২৬/৩০  (87%)  A
 4  নাজমা বেগম          ২৫/৩০  (83%)  A
 5  রাফি আহমেদ          ২৪/৩০  (80%)  A
...
35  করিম মিয়া           ৮/৩০   (27%)  F

━━━ Stats ━━━━━━━━━━━━━━━━━━━━━━━━━━
সর্বোচ্চ: ২৯  |  গড়: ২২.৪  |  পাস: ৮৫.৭%

[📄 PDF Merit List]
```

**Offline exam Leaderboard:**
```
🏆 Leaderboard
Chemistry CQ — April 2025
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                [📋 Offline Exam]

🥇  সাদিয়া ইসলাম      ৪৫/৫০  (90%)  A+
🥈  তানভীর হোসেন       ৪০/৫০  (80%)  A
🥉  রহিম উদ্দিন        ৩৮/৫০  (76%)  A-
 4  নাজমা বেগম          ৩৫/৫০  (70%)  A-
...
 7  করিম মিয়া           ১৮/৫০  (36%)  F
⚪  রাফি আহমেদ          Absent

━━━ Stats ━━━━━━━━━━━━━━━━━━━━━━━━━━
অংশগ্রহণ: ৬/৭ (রাফি অনুপস্থিত)
গড়: ৩৬.৫  |  পাস: ৫ জন (৮৩%)
```

---

## A6. Live Monitor (Online only)

```
🔴 LIVE — Chemistry MCQ  |  ⏱ 18:32 বাকি
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

শুরু করেছে: ২৩  |  Submit: ৫  |  শুরু করেনি: ১২

🟢 রহিম উদ্দিন     — Q 18/30 চলছে
✅ সাদিয়া ইসলাম   — Submitted (২৫ মিনিট)
⬜ করিম মিয়া       — শুরু করেনি

[⏹ Force End]  [📢 Reminder পাঠাও]
```

---

# 🎓 STUDENT SIDE

## S1. Exam List

```
পরীক্ষা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tabs: [আসছে] [চলছে 🔴] [শেষ হয়েছে]

┌──────────────────────────────────────────┐
│ 🔴 চলছে!  🌐  Chemistry MCQ — CH5       │
│ ⏱ ১৮ মিনিট বাকি                        │
│ [▶️ Continue করুন]                       │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ 📅  📋  Chemistry CQ — April 2025        │
│ ১৫ এপ্রিল ২০২৫  |  সকাল ১০টা          │
│ 📍 Classroom 1                           │
│ অধ্যায় ৩-৫ থেকে সৃজনশীল প্রশ্ন।       │
│ ⏰ ৫ দিন বাকি                            │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ ✅  🌐  Physics MCQ — CH3                │
│ Score: ২২/৩০  |  A  |  Rank: #5         │
│ [📊 Result]  [🏆 Leaderboard]            │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ ✅  📋  Chemistry CQ — March             │
│ Score: ৩৮/৫০  |  A-  |  Rank: #3        │
│ [📊 Result]  [🏆 Leaderboard]            │
└──────────────────────────────────────────┘
```

**Offline exam card (upcoming):**
- শুধু নাম, বিবরণ, তারিখ, সময়, স্থান দেখাবে
- কোনো "Start" button নেই — physical-এ যেতে হবে

## S2. Online Exam — Taking Screen (same as before)

Timer, question navigator, mark for review, auto-submit — সব আগের মতো।

## S3. 🏆 Leaderboard (Student View)

```
🏆 Leaderboard
Chemistry MCQ — Chapter 5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🥇  সাদিয়া ইসলাম    ২৯/৩০  A+
🥈  রহিম উদ্দিন      ২৭/৩০  A+
🥉  তানভীর হোসেন     ২৬/৩০  A
 4  নাজমা বেগম        ২৫/৩০  A

━━━━━━━━━━━━━ তোমার অবস্থান ━━━━━━━━━━━━

 2  রহিম উদ্দিন      ২৭/৩০  A+  (তুমি)  🟢

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 5  করিম মিয়া        ২৪/৩০  A
 ...
35  নুর হোসেন         ৮/৩০   F

ক্লাস গড়: ২২.৪ / ৩০  (৭৫%)
তোমার Score: ২৭ → গড়ের চেয়ে ৪.৬ বেশি 🎯
```

Student নিজের rank highlighted দেখবে (scroll করলে auto-scroll করে নিজের row-এ)।

---

# 🔧 KEY CODE

```dart
// Offline result bulk save
Future<void> saveOfflineResults({
  required String examId,
  required double totalMarks,
  required double passMarks,
  required List<OfflineResultEntry> entries,
}) async {
  final rows = entries.where((e) => !e.isAbsent).map((e) {
    final pct = e.score / totalMarks * 100;
    return {
      'exam_id': examId,
      'student_id': e.studentId,
      'exam_type': 'offline',
      'score': e.score,
      'total_marks': totalMarks,
      'percentage': pct.toStringAsFixed(2),
      'grade': _getGrade(pct),
      'grade_point': _getGradePoint(pct),
      'is_passed': e.score >= passMarks,
      'remarks': e.remarks,
      'created_by': currentAdminId,
    };
  }).toList();

  await supabase.from('results').upsert(rows);
  // Calculate ranks
  await supabase.rpc('calculate_exam_ranks', params: {'p_exam_id': examId});
}

// Leaderboard query (works for both online + offline)
Future<List<LeaderboardEntry>> getLeaderboard(String examId) async {
  return (await supabase
      .from('results')
      .select('rank, score, total_marks, percentage, grade, is_passed, users!student_id(full_name_bn, avatar_url, student_id)')
      .eq('exam_id', examId)
      .eq('is_published', true)
      .order('rank'))
      .map(LeaderboardEntry.fromJson).toList();
}
```

---

# ✅ FEATURE CHECKLIST

## Admin:
- [ ] Exam list with type badge (🌐 Online / 📋 Offline)
- [ ] Create Online MCQ (full flow)
- [ ] **Create Offline Exam** (name + description + date/time/venue)
- [ ] Notify students on offline exam create
- [ ] Online: live monitor, force end, auto score
- [ ] **Offline: result entry** (total marks + per-student score)
- [ ] Offline: absent marking
- [ ] Grade auto-assign on score input
- [ ] Rank calculate (both types)
- [ ] **Leaderboard view** (per exam, online + offline)
- [ ] Publish results → student notification
- [ ] Merit List PDF

## Student:
- [ ] Exam list (🌐/📋 badge)
- [ ] Offline exam: show name/desc/date/time/venue (no start button)
- [ ] Online exam: full taking flow
- [ ] **Leaderboard** (own rank highlighted, auto-scroll)
- [ ] Result detail + answer review (online)
- [ ] Notification: offline exam scheduled
- [ ] Notification: result published
