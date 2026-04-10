# 📊 RESULT MANAGEMENT SYSTEM — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)
### Online MCQ + Offline Physical Exam Results

---

# 🗄️ DATABASE SCHEMA

```sql
-- results table (unified — same table for online + offline)
-- schema already defined in 09_mcq_exam_system.md

-- Rank calculation (PostgreSQL)
CREATE OR REPLACE FUNCTION calculate_exam_ranks(p_exam_id UUID)
RETURNS VOID AS $$
  UPDATE results SET rank = r.r FROM (
    SELECT id,
      DENSE_RANK() OVER (
        PARTITION BY exam_id
        ORDER BY score DESC, time_taken_seconds ASC NULLS LAST
      ) AS r
    FROM results WHERE exam_id = p_exam_id
  ) r WHERE results.id = r.id;
$$ LANGUAGE SQL;

-- View count increment
CREATE OR REPLACE FUNCTION increment_view_count(note_id UUID)
RETURNS VOID AS $$
  UPDATE notes SET view_count = view_count + 1 WHERE id = note_id;
$$ LANGUAGE SQL;
```

---

# 👨‍💼 ADMIN SIDE

## A1. Result Dashboard

```
📊 ফলাফল ব্যবস্থাপনা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tabs: [🌐 Online MCQ] [📋 Offline] [সব]

━━━ Online MCQ ━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────┐
│ 🌐 Chemistry MCQ — CH5  |  ১০ এপ্রিল    │
│ ৩৫/৪০ জন  |  ⚙️ Score ও Rank ready       │
│ Status: 🟡 Unpublished                   │
│ [📊 Preview]  [✅ Publish]  [🏆 LB]     │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│ 🌐 Physics MCQ — CH3  |  ০৫ এপ্রিল      │
│ Status: ✅ Published                     │
│ [📊 Result]  [🏆 Leaderboard]  [📄 PDF] │
└──────────────────────────────────────────┘

━━━ Offline Exam ━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────┐
│ 📋 Chemistry CQ — April  |  ১৫ এপ্রিল   │
│ Status: 🔴 Result দেওয়া হয়নি            │
│ [📊 Result Upload করুন]                  │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│ 📋 Math CQ — March  |  ২৫ মার্চ          │
│ Status: ✅ Published                     │
│ [📊 Result]  [🏆 Leaderboard]  [📄 PDF] │
└──────────────────────────────────────────┘
```

## A2. Online MCQ Result Preview & Publish

```
Chemistry MCQ — CH5  |  Result Preview
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Overview:
  অংশগ্রহণ: ৩৫/৪০ জন
  সর্বোচ্চ: ২৯  |  গড়: ২২.৪  |  সর্বনিম্ন: ৮
  পাস: ৩০ (৮৫.৭%)  |  ফেল: ৫

Score Distribution (Histogram):
  0-10  : ██ ৫ জন
  11-20 : ████████ ১০ জন
  21-30 : ████████████████ ২০ জন

Merit List Preview:
Rank | নাম           | Score | %  | Grade | সময়
  1  | সাদিয়া       | ২৯/৩০ | 97 | A+    | 25:14
  2  | রহিম          | ২৭/৩০ | 90 | A+    | 27:33
  3  | তানভীর        | ২৬/৩০ | 87 | A     | 28:01
  ...

[✅ Result Publish করুন]
→ সব অংশগ্রহণকারীর কাছে notification যাবে
```

## A3. Offline Result Upload

```
📋 Offline Result Upload
Chemistry CQ — April 2025 | ১৫ এপ্রিল
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1 — পূর্ণমান:
পূর্ণমান:  [৫০]
পাস নম্বর: [২০]

Step 2 — শিক্ষার্থীদের নম্বর:
🔍 [নাম খুঁজুন...]

┌──────────────────────────────────────────────┐
│ নাম              | নম্বর       | Grade | Pass │
├──────────────────────────────────────────────┤
│ রহিম উদ্দিন      │ [৩৮     ]  │ A-    │ ✅  │
│ সাদিয়া ইসলাম    │ [৪৫     ]  │ A+    │ ✅  │
│ তানভীর হোসেন     │ [৪০     ]  │ A     │ ✅  │
│ করিম মিয়া        │ [১৮     ]  │ F     │ ❌  │
│ রাফি আহমেদ       │ [absent ]  │  —    │ ⚪  │
└──────────────────────────────────────────────┘

"absent" টাইপ = পরীক্ষায় ছিল না, result-এ দেখাবে না

মন্তব্য (optional):
[অধ্যায় ৫ আরও মনোযোগ দিতে হবে।]

[✅ Save করুন]   [✅ Save + Publish করুন]
```

## A4. Result Table (Published — per Exam)

**Online MCQ:**
```
Chemistry MCQ — CH5  |  ফলাফল
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ফিল্টার: [সব ▼]  সাজাও: [Rank ▼]
🔍 [নাম / আইডি]

Rank | নাম          | Score  | %  | Grade | Pass | সময়
  1  | সাদিয়া       | ২৯/৩০ | 97 | A+    | ✅   | 25:14
  2  | রহিম          | ২৭/৩০ | 90 | A+    | ✅   | 27:33
  ...
 35  | করিম          |  ৮/৩০ | 27 | F     | ❌   | 30:00⏰

[📄 Merit List PDF]  [📊 CSV Export]  [🏆 Leaderboard]
```

**Offline Exam:**
```
Chemistry CQ — April  |  ফলাফল
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Rank | নাম          | Score  | %  | Grade | Pass
  1  | সাদিয়া       | ৪৫/৫০ | 90 | A+    | ✅
  2  | তানভীর        | ৪০/৫০ | 80 | A     | ✅
  3  | রহিম          | ৩৮/৫০ | 76 | A-    | ✅
  4  | করিম          | ১৮/৫০ | 36 | F     | ❌
 ⚪  | রাফি          | Absent |  — |  —    |  —

[📄 Merit List PDF]  [🏆 Leaderboard]
```

## A5. 🏆 Leaderboard (Admin View)

```
🏆 Leaderboard
Chemistry MCQ — Chapter 5  |  🌐 Online
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🥇  সাদিয়া ইসলাম    [Avatar]  ২৯/৩০  97%  A+
🥈  রহিম উদ্দিন      [Avatar]  ২৭/৩০  90%  A+
🥉  তানভীর হোসেন     [Avatar]  ২৬/৩০  87%  A
 4  নাজমা বেগম                  ২৫/৩০  83%  A
 5  রাফি আহমেদ                  ২৪/৩০  80%  A
 ...
35  করিম মিয়া                   ৮/৩০   27%  F

━━━ Stats ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
অংশগ্রহণ: ৩৫/৪০  |  গড়: ২২.৪  |  পাস: ৮৫.৭%

[📄 PDF Merit List]
```

## A6. Student Performance (Admin View)

Student profile → Result tab:

```
রহিম উদ্দিন — পারফরম্যান্স
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

গড় Score: ৮২%  |  গড় Rank: #৩  |  পাস: ১০০%

Score Trend (Line Chart — শেষ ৬টি পরীক্ষা):
[Chart]

বিষয়ভিত্তিক গড় (Radar Chart):
রসায়ন: ৮৫%  পদার্থ: ৭৮%  গণিত: ৯১%

সাম্প্রতিক ফলাফল:
পরীক্ষা             | Type    | Score | Rank | তারিখ
Chemistry MCQ CH5   | 🌐 MCQ  | 27/30 | #2   | ১০ এপ্রিল
Chemistry CQ April  | 📋 Offline| 38/50 | #3  | ১৫ এপ্রিল
Physics MCQ CH3     | 🌐 MCQ  | 22/30 | #5   | ০৫ এপ্রিল
Math CQ March       | 📋 Offline| 40/50 | #2  | ২৫ মার্চ
```

## A7. Result Card PDF

```
╔══════════════════════════════════════════════╗
║        🌟 RADIANCE COACHING CENTER           ║
║        টঙ্গী, গাজীপুর                        ║
╠══════════════════════════════════════════════╣
║  RESULT CARD                                 ║
╠══════════════════════════════════════════════╣
║  [Photo]  রহিম উদ্দিন  |  RCC-2025-012      ║
║           HSC Biology Batch 2025             ║
╠══════════════════════════════════════════════╣
║  পরীক্ষা: Chemistry CQ — April 2025         ║
║  ধরন: Offline Exam  |  তারিখ: ১৫ এপ্রিল   ║
╠══════════════════════════════════════════════╣
║  Score:      ৩৮ / ৫০                        ║
║  Percentage: ৭৬%                            ║
║  Grade:      A-                              ║
║  Rank:       #3 (৭ জনের মধ্যে)              ║
║  Status:     ✅ PASSED                       ║
╠══════════════════════════════════════════════╣
║  মন্তব্য: অধ্যায় ৫ আরও মনোযোগ দিতে হবে।  ║
║                  Signature: ___________      ║
╚══════════════════════════════════════════════╝
```

---

# 🎓 STUDENT SIDE

## S1. My Results List

```
আমার ফলাফল
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tabs: [সব] [🌐 Online] [📋 Offline]

Summary: গড় ৮২%  |  মোট ৮টি  |  পাস ৮/৮

━━━ এপ্রিল ২০২৫ ━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────┐
│ 🌐  Chemistry MCQ — CH5                  │
│ ২৭/৩০  |  A+  |  Rank: #2               │
│ [📊 বিস্তারিত]  [🏆 Leaderboard]  [📄]  │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ 📋  Chemistry CQ — April 2025            │
│ ৩৮/৫০  |  A-  |  Rank: #3               │
│ মন্তব্য: অধ্যায় ৫ আরও মনোযোগ দাও।      │
│ [📊 বিস্তারিত]  [🏆 Leaderboard]  [📄]  │
└──────────────────────────────────────────┘

━━━ মার্চ ২০২৫ ━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────┐
│ 📋  Math CQ — March                      │
│ ৪০/৫০  |  A  |  Rank: #2                │
│ [📊 বিস্তারিত]  [🏆 Leaderboard]  [📄]  │
└──────────────────────────────────────────┘
```

## S2. Result Detail

```
Chemistry MCQ — Chapter 5  |  🌐 Online
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────┐ ┌──────────┐ ┌──────────┐
│  27/30   │ │   A+     │ │  Rank #2  │
└──────────┘ └──────────┘ └──────────┘

✅ সঠিক: ২৭  ❌ ভুল: ৩  ○ বাদ: ০
নেগেটিভ: -০.৭৫  |  সময়: ২৭:৩৩

Class vs Me:
Class avg  ████████████░░░░  75%
My score   ████████████████  90%

[📋 উত্তর পর্যালোচনা]  [🏆 Leaderboard]  [📄 Card]
```

**Offline Result Detail:**
```
Chemistry CQ — April 2025  |  📋 Offline
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────┐ ┌──────────┐ ┌──────────┐
│  38/50   │ │   A-     │ │  Rank #3  │
└──────────┘ └──────────┘ └──────────┘

Percentage: ৭৬%  |  Status: ✅ পাস

মন্তব্য:
"অধ্যায় ৫ আরও মনোযোগ দিতে হবে।"

Class vs Me:
Class avg  ████████████░░░░  73%
My score   ████████████████  76%

[🏆 Leaderboard]  [📄 Result Card]
```

## S3. 🏆 Leaderboard (Student View)

```
🏆 Leaderboard
Chemistry CQ — April 2025  |  📋 Offline
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🥇  সাদিয়া ইসলাম    ৪৫/৫০  90%  A+
🥈  তানভীর হোসেন     ৪০/৫০  80%  A
🥉  রহিম উদ্দিন      ৩৮/৫০  76%  A-  ← তুমি 🟢
 4  নাজমা বেগম        ৩৫/৫০  70%  A-
 5  মিম আক্তার        ২৮/৫০  56%  C
 6  জাহিদ হোসেন       ২৪/৫০  48%  D
 7  করিম মিয়া         ১৮/৫০  36%  F
⚪  রাফি আহমেদ        Absent

ক্লাস গড়: ৩৬.৫/৫০  (৭৩%)
তোমার Score গড়ের চেয়ে ১.৫ বেশি 📈

[📄 PDF]
```

নিজের row auto-highlighted + scroll করলে auto-navigate করে নিজের position-এ।

## S4. Performance Analytics

```
আমার পারফরম্যান্স
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Score Trend (Line Chart — শেষ ৬ পরীক্ষা):
📈 ধীরে ধীরে উন্নতি হচ্ছে!

বিষয়ভিত্তিক গড় (Radar Chart):
রসায়ন:  ৮৫%  পদার্থ: ৭৮%  গণিত: ৯১%

সেরা বিষয়:  গণিত (৯১%)
দুর্বল বিষয়: পদার্থ (৭৮%) — আরও মনোযোগ দাও

সাম্প্রতিক:
পরীক্ষা            | Type    | Score | Rank
Chemistry MCQ CH5  | 🌐      | 27/30 | #2
Chemistry CQ April | 📋      | 38/50 | #3
Physics MCQ CH3    | 🌐      | 22/30 | #5
Math CQ March      | 📋      | 40/50 | #2
```

---

# 🔧 KEY CODE

```dart
class ResultRepository {

  // Online MCQ — auto calculate after all submissions
  Future<void> calculateOnlineResults(String examId) async {
    final exam = await supabase.from('exams').select().eq('id', examId).single();
    final questions = await supabase.from('exam_questions').select().eq('exam_id', examId);
    final submissions = await supabase.from('exam_submissions').select().eq('exam_id', examId);

    final results = submissions.map((sub) {
      final answers = sub['answers'] as Map<String, dynamic>;
      double score = 0; int correct = 0, wrong = 0, skipped = 0;

      for (final q in questions) {
        final selected = answers[q['id']] as String?;
        if (selected == null) { skipped++; }
        else if (selected == q['correct_option']) { score += (q['marks'] as num); correct++; }
        else { score -= (exam['negative_marking'] as num); wrong++; }
      }
      score = score.clamp(0, exam['total_marks'] as double);
      final pct = score / (exam['total_marks'] as num) * 100;

      return {
        'exam_id': examId,
        'student_id': sub['student_id'],
        'exam_type': 'online',
        'score': score,
        'total_marks': exam['total_marks'],
        'percentage': pct.toStringAsFixed(2),
        'total_correct': correct, 'total_wrong': wrong, 'total_skipped': skipped,
        'negative_deduction': wrong * (exam['negative_marking'] as num),
        'grade': _grade(pct), 'grade_point': _gradePoint(pct),
        'is_passed': score >= (exam['pass_marks'] as num),
        'time_taken_seconds': sub['started_at'] != null && sub['submitted_at'] != null
            ? DateTime.parse(sub['submitted_at']).difference(DateTime.parse(sub['started_at'])).inSeconds
            : null,
      };
    }).toList();

    await supabase.from('results').upsert(results);
    await supabase.rpc('calculate_exam_ranks', params: {'p_exam_id': examId});
  }

  // Offline — admin uploads marks
  Future<void> saveOfflineResults({
    required String examId,
    required double totalMarks,
    required double passMarks,
    required List<OfflineEntry> entries,
  }) async {
    final rows = entries.where((e) => !e.isAbsent).map((e) {
      final pct = e.score / totalMarks * 100;
      return {
        'exam_id': examId, 'student_id': e.studentId, 'exam_type': 'offline',
        'score': e.score, 'total_marks': totalMarks,
        'percentage': pct.toStringAsFixed(2),
        'grade': _grade(pct), 'grade_point': _gradePoint(pct),
        'is_passed': e.score >= passMarks,
        'remarks': e.remarks, 'created_by': currentAdminId,
      };
    }).toList();

    await supabase.from('results').upsert(rows);
    await supabase.rpc('calculate_exam_ranks', params: {'p_exam_id': examId});
  }

  // Leaderboard (works for both types)
  Future<List<LeaderboardEntry>> getLeaderboard(String examId) async {
    return (await supabase
        .from('results')
        .select('rank, score, total_marks, percentage, grade, is_passed, '
                'users!student_id(full_name_bn, avatar_url, student_id)')
        .eq('exam_id', examId).eq('is_published', true).order('rank'))
        .map(LeaderboardEntry.fromJson).toList();
  }

  // Publish + notify
  Future<void> publishResults(String examId) async {
    await supabase.from('results')
        .update({'is_published': true, 'published_at': DateTime.now().toIso8601String()})
        .eq('exam_id', examId);
    // FCM notification to all participants
    await _notifyResultPublished(examId);
  }

  String _grade(double pct) {
    if (pct >= 90) return 'A+'; if (pct >= 80) return 'A';
    if (pct >= 70) return 'A-'; if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';  if (pct >= 40) return 'D';
    return 'F';
  }
}
```

---

# ✅ FEATURE CHECKLIST

## Admin:
- [ ] Result dashboard (online + offline tabs)
- [ ] Online: auto score → grade → rank → preview → publish
- [ ] **Offline: result upload** (total marks + per-student marks)
- [ ] Offline: absent marking
- [ ] Offline: auto grade on input
- [ ] Both: rank calculate (DENSE_RANK)
- [ ] Both: publish → student notification
- [ ] **Leaderboard** (per exam, 🥇🥈🥉 medals)
- [ ] Per-exam result table (filter, search)
- [ ] Student Result Card PDF (online + offline, remarks shown)
- [ ] Merit List PDF
- [ ] Student performance analytics (admin view)

## Student:
- [ ] Results list (🌐/📋 type badge, all exams)
- [ ] Online result detail (correct/wrong/negative + class comparison)
- [ ] Offline result detail (score/grade/rank + teacher remarks)
- [ ] Answer review (online only)
- [ ] **Leaderboard** (own row highlighted, auto-scroll)
- [ ] Performance analytics (trend + radar chart)
- [ ] Result Card PDF download + share
- [ ] Notification when result published
