# 💬 DOUBT SOLVING SYSTEM — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)

---

## 📌 Overview

Doubt solving **২ ভাবে** হবে:

| Type | কীভাবে |
|---|---|
| **Chat-based** | Admin প্রতিটি doubt-এর dedicated chat box-এ reply করবে |
| **Scheduled Meeting** | Admin একটা meeting link + সময় দিয়ে দেবে |

**Solved হলে:**
- Student বা Admin যেকোনো জন "✅ Solved" button press করবে
- Total solved count বাড়বে (student-এর profile-এ + global stats-এ)
- Doubt টা database থেকে **delete** হয়ে যাবে (soft delete না — hard delete)

---

# 🗄️ DATABASE SCHEMA

```sql
-- =============================================
-- DOUBTS
-- =============================================
CREATE TABLE doubts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id UUID REFERENCES courses(id),
  subject TEXT,                        -- "রসায়ন", "পদার্থ" (free text)
  chapter TEXT,                        -- "অধ্যায় ৩: মোলের ধারণা"
  title TEXT NOT NULL,                 -- Short title
  description TEXT NOT NULL,           -- Detailed doubt (MD supported)
  image_url TEXT,                      -- Optional image (Supabase Storage)

  -- Resolution type (set by admin)
  resolution_type VARCHAR(20)
    CHECK (resolution_type IN ('chat', 'meeting', NULL)),

  -- If meeting:
  meeting_link TEXT,                   -- Google Meet / Zoom link
  meeting_time TIMESTAMPTZ,            -- Scheduled time
  meeting_note TEXT,                   -- Extra note for meeting

  status VARCHAR(20) NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'meeting_scheduled', 'solved')),

  solved_by UUID REFERENCES users(id), -- Who clicked solved
  solved_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- DOUBT CHAT MESSAGES
-- =============================================
CREATE TABLE doubt_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doubt_id UUID NOT NULL REFERENCES doubts(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,               -- MD supported
  image_url TEXT,                      -- Optional image in message
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- SOLVED COUNT TRACKER (per student)
-- =============================================
CREATE TABLE student_doubt_stats (
  student_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  total_submitted INT DEFAULT 0,
  total_solved INT DEFAULT 0,
  last_solved_at TIMESTAMPTZ
);

-- Auto-increment stats on doubt insert
CREATE OR REPLACE FUNCTION increment_doubt_submitted()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO student_doubt_stats (student_id, total_submitted)
  VALUES (NEW.student_id, 1)
  ON CONFLICT (student_id)
  DO UPDATE SET total_submitted = student_doubt_stats.total_submitted + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_doubt_submitted
  AFTER INSERT ON doubts
  FOR EACH ROW EXECUTE FUNCTION increment_doubt_submitted();

-- Auto-increment solved + hard delete on status=solved
CREATE OR REPLACE FUNCTION on_doubt_solved()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'solved' AND OLD.status != 'solved' THEN
    -- Increment solved count
    INSERT INTO student_doubt_stats (student_id, total_solved, last_solved_at)
    VALUES (NEW.student_id, 1, now())
    ON CONFLICT (student_id)
    DO UPDATE SET
      total_solved = student_doubt_stats.total_solved + 1,
      last_solved_at = now();

    -- Schedule hard delete after 1 minute (or do it immediately)
    -- We'll handle hard delete from Flutter after showing success animation
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_doubt_solved
  AFTER UPDATE ON doubts
  FOR EACH ROW EXECUTE FUNCTION on_doubt_solved();
```

---

# 👨‍💼 ADMIN SIDE

---

## A1. Doubt Inbox (Admin Home)

```
💬 Doubt Inbox
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────┐ ┌──────────┐ ┌──────────┐
│ 🔴 Open  │ │ 🔵 Active│ │ 📅 Meet  │
│ Doubts   │ │ Chats    │ │ Scheduled│
│   ১২     │ │    ৫     │ │    ৩     │
└──────────┘ └──────────┘ └──────────┘

ফিল্টার: [সব ▼] [🔴 Open] [🔵 Chat চলছে] [📅 Meeting]
কোর্স: [সব কোর্স ▼]

━━━ নতুন Doubts ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────────┐
│ 🔴 নতুন  |  রহিম উদ্দিন  |  রসায়ন         │
│ মোলার ঘনত্ব আর মোলালিটির পার্থক্য কী?      │
│ ১০ মিনিট আগে                                │
│ [💬 Chat করুন]  [📅 Meeting দিন]  [✅ Solved]│
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ 🔵 Chat চলছে  |  সাদিয়া ইসলাম  |  পদার্থ  │
│ নিউটনের ২য় সূত্র বুঝতে পারছি না।          │
│ ২ ঘণ্টা আগে  |  ৩টি message                │
│ [💬 Chat খুলুন]                              │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ 📅 Meeting Scheduled  |  করিম মিয়া          │
│ লগারিদম সমস্যা                               │
│ ১১ এপ্রিল, বিকাল ৪টা  |  Meet link দেওয়া আছে│
│ [💬 Chat খুলুন]  [✅ Solved]                 │
└──────────────────────────────────────────────┘
```

---

## A2. Doubt Detail + Chat Screen (Admin)

Admin এই screen থেকে:
- Chat করবে অথবা
- Meeting schedule দেবে

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
← রহিম উদ্দিন  |  রসায়ন             [✅ Solved]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────┐
│ 📌 Doubt                                    │
│                                             │
│ বিষয়: রসায়ন  |  অধ্যায় ৩                │
│                                             │
│ মোলার ঘনত্ব আর মোলালিটির পার্থক্য কী?     │
│ দুইটা কি একই জিনিস? নাকি আলাদা?           │
│                                             │
│ [📷 Student-এর ছবি] (যদি দিয়ে থাকে)        │
│                                             │
│ ১০ মিনিট আগে                               │
└─────────────────────────────────────────────┘

━━━ Resolution Type ━━━━━━━━━━━━━━━━━━━━━━━━━━

[💬 Chat করে সমাধান দিন]  [📅 Meeting Schedule করুন]

━━━ Chat ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

(Chat শুরু হলে messages এখানে দেখাবে)

                            আপনি (Admin)  ২:৩০ PM
                          মোলার ঘনত্র = mol/L
                          মোলালিটি = mol/kg
                          দুইটা আলাদা। বিস্তারিত
                          নিচে দেখো 👇

Admin  ২:৩১ PM
$$C = \frac{n}{V(\text{L})}$$ (মোলারিটি)
$$m = \frac{n}{W(\text{kg})}$$ (মোলালিটি)

রহিম  ২:৩৫ PM
স্যার, বুঝতে পারছি। তাহলে...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[📷]  [Type here — Markdown/LaTeX সমর্থিত]  [➤]
```

### Meeting Schedule করলে:

```
📅 Meeting Schedule করুন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

তারিখ ও সময়:
┌──────────────────────────────────────┐
│ 📅 ১১ এপ্রিল ২০২৫, বিকাল ৪:০০ টা   │
└──────────────────────────────────────┘

Meeting Link:
┌──────────────────────────────────────┐
│ https://meet.google.com/abc-xyz-123  │
└──────────────────────────────────────┘

Student-এর জন্য নোট:
┌──────────────────────────────────────┐
│ লগারিদমের chapter ভালো করে পড়ে নিও│
│ আসার আগে।                            │
└──────────────────────────────────────┘

[📤 Schedule পাঠাও]
```

Schedule করলে:
- Doubt status: `meeting_scheduled`
- Student-এর কাছে push notification + SMS যাবে
- Chat-এ system message আসবে:

```
📅 Meeting Scheduled
তারিখ: ১১ এপ্রিল, বিকাল ৪:০০ টা
Link: meet.google.com/abc-xyz-123
নোট: লগারিদমের chapter পড়ে নাও।
```

---

## A3. ✅ Solved — Admin Side

যেকোনো doubt থেকে:
```
[✅ Solved] button press
    ↓
Confirm Dialog:
"এই doubt টি সমাধান হিসেবে চিহ্নিত করবেন?
এটি মুছে যাবে।"
    ↓
[হ্যাঁ, Solved করুন]
    ↓
1. doubts table: status = 'solved', solved_by = admin_id, solved_at = now()
2. student_doubt_stats: total_solved + 1
3. Student-কে push notification: "তোমার doubt সমাধান হয়েছে! ✅"
4. Confetti animation (brief)
5. Hard delete: doubts + doubt_messages (CASCADE)
6. Inbox থেকে সরে যায়
```

---

## A4. Admin Stats (Dashboard-এ):

```
💬 Doubt Stats
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
মোট Solved (এই মাস): ৪৭টি
Open Doubts:          ১২টি
Average Response:     ৩.২ ঘণ্টা
```

---

# 🎓 STUDENT SIDE

---

## S1. Submit Doubt Screen

```
❓ নতুন Doubt জমা দাও
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

বিষয়:   [রসায়ন                      ]
অধ্যায়: [অধ্যায় ৩: মোলের ধারণা     ]

শিরোনাম:
┌──────────────────────────────────────┐
│ মোলার ঘনত্ব আর মোলালিটির পার্থক্য?  │
└──────────────────────────────────────┘

বিস্তারিত লিখুন:
┌──────────────────────────────────────┐
│ দুইটা কি একই জিনিস? নাকি আলাদা?   │
│ বইতে দুইটা সূত্র দেখলাম কিন্তু     │
│ পার্থক্যটা ধরতে পারছি না।           │
└──────────────────────────────────────┘

[📷 ছবি যোগ করুন] (question-এর photo তুলে দিতে পারো)

[📤 Doubt জমা দাও]
```

---

## S2. My Doubts Screen

```
আমার Doubts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────┐ ┌──────────┐
│ 📤 জমা দেওয়া│ │ ✅ Solved  │
│    ২৩    │ │    ১৯    │
└──────────┘ └──────────┘

━━━ Open Doubts (৪টি) ━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────────┐
│ 🔵 Reply আসছে  |  রসায়ন                     │
│ মোলার ঘনত্ব আর মোলালিটির পার্থক্য?          │
│ ১ ঘণ্টা আগে  |  স্যার reply দিয়েছেন (৩টি)   │
│ [💬 Chat দেখুন]  [✅ Solved]                 │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ 📅 Meeting Scheduled  |  গণিত               │
│ লগারিদম সমস্যা                               │
│ ১১ এপ্রিল, বিকাল ৪টা                        │
│ [🔗 Join Meeting]  [💬 Chat]  [✅ Solved]    │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ 🔴 Open  |  পদার্থবিজ্ঞান                   │
│ নিউটনের ২য় সূত্র                             │
│ ৩০ মিনিট আগে  |  এখনো reply হয়নি           │
│ [💬 Chat দেখুন]  [✅ Solved]                 │
└──────────────────────────────────────────────┘

[➕ নতুন Doubt জমা দাও]
```

---

## S3. Doubt Chat Screen (Student)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
← রসায়ন — মোলার ঘনত্ব...    [✅ Solved]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────┐
│ 📌 তোমার Doubt                      │
│ মোলার ঘনত্র আর মোলালিটির পার্থক্য? │
└─────────────────────────────────────┘

Admin (স্যার)  ২:৩০ PM
মোলার ঘনত্র = mol/L, মোলালিটি = mol/kg

Admin (স্যার)  ২:৩১ PM
$$C = \frac{n}{V(\text{L})}$$ ← মোলারিটি
$$m = \frac{n}{W(\text{kg})}$$ ← মোলালিটি

                          তুমি  ২:৩৫ PM
বুঝতে পারছি স্যার! তাহলে
temperature-এ পরিবর্তনে
কোনটা change হয়?

Admin (স্যার)  ২:৩৭ PM
মোলারিটি change হয় (V change হয়)।
মোলালিটি হয় না (kg change হয় না)।

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[📷]  [এখানে লিখুন...              ] [➤]
```

---

## S4. ✅ Solved — Student Side

Student নিজে solved করতে পারবে (doubt বুঝে গেলে):

```
[✅ Solved] press
    ↓
Confirm Dialog:
"Doubt টি সমাধান হয়েছে?"
[হ্যাঁ ✅]
    ↓
1. status = 'solved'
2. Solved count + 1 (profile-এ দেখাবে)
3. ✨ Confetti / celebration animation
4. Hard delete হয়ে যাবে
5. My Doubts থেকে সরে যাবে
```

**Solved confirmation animation:**
```
✅ Doubt Solved!

তোমার মোট সমাধান: ২০টি 🎉

[চমৎকার! 🏠 হোমে যাও]
```

---

## S5. Meeting Join

Meeting scheduled হলে:

```
┌──────────────────────────────────────────────┐
│ 📅 Meeting Scheduled                         │
│                                              │
│ তারিখ: ১১ এপ্রিল ২০২৫                       │
│ সময়:   বিকাল ৪:০০ টা                        │
│ স্যারের নোট: লগারিদমের chapter পড়ে নিও।   │
│                                              │
│ [🔗 Meeting-এ Join করুন]                    │
│  (url_launcher দিয়ে Meet/Zoom খুলবে)         │
│                                              │
│ ⏰ ৫ ঘণ্টা ১৫ মিনিট বাকি                   │
└──────────────────────────────────────────────┘
```

Meeting-এর ৩০ মিনিট আগে push notification + SMS যাবে।

---

## S6. Student Profile — Doubt Stats

```
👤 রহিম উদ্দিন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💬 Doubt Stats:
┌──────────┐ ┌──────────┐
│ 📤 জমা   │ │ ✅ Solved │
│    ২৩    │ │    ১৯    │
└──────────┘ └──────────┘
সমাধানের হার: ৮৩%
```

---

# 🔧 FLUTTER IMPLEMENTATION

## Doubt Repository:

```dart
class DoubtRepository {
  final SupabaseClient _supabase;

  // Student submits doubt
  Future<Doubt> submitDoubt({
    required String studentId,
    required String title,
    required String description,
    String? courseId,
    String? subject,
    String? chapter,
    File? image,
  }) async {
    String? imageUrl;
    if (image != null) {
      // Upload to Supabase Storage
      imageUrl = await _uploadImage(image, studentId);
    }
    final res = await _supabase.from('doubts').insert({
      'student_id': studentId,
      'title': title,
      'description': description,
      'course_id': courseId,
      'subject': subject,
      'chapter': chapter,
      'image_url': imageUrl,
    }).select().single();
    return Doubt.fromJson(res);
  }

  // Admin: get all open doubts
  Future<List<Doubt>> getOpenDoubts({String? courseId}) async {
    var query = _supabase
        .from('doubts')
        .select('*, users!student_id(full_name_bn, avatar_url)')
        .neq('status', 'solved')
        .order('created_at', ascending: false);
    if (courseId != null) query = query.eq('course_id', courseId);
    return (await query).map((e) => Doubt.fromJson(e)).toList();
  }

  // Get messages for a doubt (Realtime subscription)
  Stream<List<DoubtMessage>> watchMessages(String doubtId) {
    return _supabase
        .from('doubt_messages')
        .stream(primaryKey: ['id'])
        .eq('doubt_id', doubtId)
        .order('created_at')
        .map((rows) => rows.map(DoubtMessage.fromJson).toList());
  }

  // Send a message
  Future<void> sendMessage({
    required String doubtId,
    required String senderId,
    required String content,
    File? image,
  }) async {
    String? imageUrl;
    if (image != null) imageUrl = await _uploadImage(image, senderId);
    await _supabase.from('doubt_messages').insert({
      'doubt_id': doubtId,
      'sender_id': senderId,
      'content': content,
      'image_url': imageUrl,
    });
    // Update doubt status to in_progress if still open
    await _supabase.from('doubts')
        .update({'status': 'in_progress', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', doubtId)
        .eq('status', 'open');
  }

  // Admin: schedule meeting
  Future<void> scheduleMeeting({
    required String doubtId,
    required DateTime meetingTime,
    required String meetingLink,
    String? meetingNote,
  }) async {
    await _supabase.from('doubts').update({
      'resolution_type': 'meeting',
      'status': 'meeting_scheduled',
      'meeting_link': meetingLink,
      'meeting_time': meetingTime.toIso8601String(),
      'meeting_note': meetingNote,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', doubtId);

    // Send system message in chat
    await _supabase.from('doubt_messages').insert({
      'doubt_id': doubtId,
      'sender_id': 'SYSTEM',   // or admin id with a flag
      'content': '📅 **Meeting Scheduled**\n'
          'তারিখ: ${_formatTime(meetingTime)}\n'
          'Link: $meetingLink'
          '${meetingNote != null ? "\nনোট: $meetingNote" : ""}',
    });
  }

  // Mark as solved — then hard delete
  Future<void> markSolved({
    required String doubtId,
    required String solvedBy,
  }) async {
    // 1. Update status (trigger handles stats increment)
    await _supabase.from('doubts').update({
      'status': 'solved',
      'solved_by': solvedBy,
      'solved_at': DateTime.now().toIso8601String(),
    }).eq('id', doubtId);

    // 2. Hard delete (CASCADE deletes messages too)
    await _supabase.from('doubts').delete().eq('id', doubtId);
  }

  // Student: get own doubts
  Future<List<Doubt>> getMyDoubts(String studentId) async {
    return (await _supabase
        .from('doubts')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false))
        .map(Doubt.fromJson).toList();
  }

  // Student stats
  Future<StudentDoubtStats> getStats(String studentId) async {
    final res = await _supabase
        .from('student_doubt_stats')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    return StudentDoubtStats.fromJson(res ?? {});
  }
}
```

## Solved Flow (Flutter):

```dart
Future<void> _onSolvedPressed(BuildContext context, String doubtId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Doubt Solved?'),
      content: const Text('এই doubt টি সমাধান হিসেবে চিহ্নিত হবে এবং মুছে যাবে।'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('হ্যাঁ, Solved ✅')),
      ],
    ),
  );

  if (confirm != true) return;

  await doubtRepository.markSolved(doubtId: doubtId, solvedBy: currentUserId);

  // Show celebration
  if (context.mounted) {
    showDialog(context: context, builder: (_) => const _SolvedCelebrationDialog());
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
      context.go('/student/doubts');  // back to doubt list
    }
  }
}
```

---

# 📊 SQL QUERIES

```sql
-- Admin: open doubts with student info
SELECT d.*, u.full_name_bn, u.avatar_url,
  (SELECT COUNT(*) FROM doubt_messages WHERE doubt_id = d.id) AS message_count
FROM doubts d
JOIN users u ON d.student_id = u.id
WHERE d.status != 'solved'
ORDER BY d.created_at DESC;

-- Student: own doubts
SELECT d.*,
  (SELECT COUNT(*) FROM doubt_messages WHERE doubt_id = d.id) AS message_count
FROM doubts d
WHERE d.student_id = 'STUDENT_UUID'
ORDER BY d.created_at DESC;

-- Global solved stats (for dashboard)
SELECT
  SUM(total_submitted) AS total_submitted,
  SUM(total_solved)    AS total_solved
FROM student_doubt_stats;

-- Top students by solved doubts (leaderboard, optional)
SELECT u.full_name_bn, s.total_solved
FROM student_doubt_stats s
JOIN users u ON s.student_id = u.id
ORDER BY s.total_solved DESC
LIMIT 10;
```

---

# ✅ FEATURE CHECKLIST

## Admin:
- [ ] Doubt Inbox (open/in_progress/meeting_scheduled tabs)
- [ ] Doubt detail view (title, description, image)
- [ ] Chat reply (MD + LaTeX + image support)
- [ ] Realtime chat (Supabase Realtime)
- [ ] Schedule Meeting (date/time + link + note)
- [ ] Meeting system message in chat (auto)
- [ ] ✅ Solved button → confirm → delete → notification
- [ ] Push notification to student on reply
- [ ] Push notification to student when solved
- [ ] Filter doubts by course
- [ ] Stats on dashboard (open count, solved this month)

## Student:
- [ ] Submit doubt (subject/chapter/title/description/image)
- [ ] My Doubts list (open + meeting_scheduled)
- [ ] Chat view with admin (Realtime)
- [ ] Meeting card with Join link (url_launcher)
- [ ] Meeting reminder notification (30 min before)
- [ ] ✅ Solved button (student side) → celebration → delete
- [ ] Solved count on profile
- [ ] Push notification on admin reply
- [ ] Push notification when meeting scheduled
- [ ] SMS when meeting scheduled (with link + time)
