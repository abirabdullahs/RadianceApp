# 📅 ATTENDANCE MANAGEMENT SYSTEM — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)

---

## 📌 Overview

Physical batch-এর attendance system। Admin class-এ বসে একটা একটা করে student-এর নাম দেখবে, Present/Absent button press করবে — automatically next student-এ চলে যাবে।

---

# 🗄️ DATABASE SCHEMA

```sql
-- =============================================
-- ATTENDANCE SESSION (একটি দিনের একটি class)
-- =============================================
CREATE TABLE attendance_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES courses(id),
  session_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by UUID REFERENCES users(id),
  total_students INT DEFAULT 0,
  present_count INT DEFAULT 0,
  absent_count INT DEFAULT 0,
  is_completed BOOLEAN DEFAULT false,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(course_id, session_date)       -- একদিনে একটি course-এর একটাই session
);

-- =============================================
-- ATTENDANCE RECORDS (প্রতিটি student-এর status)
-- =============================================
CREATE TABLE attendance_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id),
  status VARCHAR(10) NOT NULL DEFAULT 'absent'
    CHECK (status IN ('present', 'absent', 'late')),
  marked_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(session_id, student_id)
);

-- =============================================
-- ATTENDANCE EDIT LOG (কে কখন change করল)
-- =============================================
CREATE TABLE attendance_edit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  record_id UUID NOT NULL REFERENCES attendance_records(id),
  old_status VARCHAR(10),
  new_status VARCHAR(10),
  changed_by UUID REFERENCES users(id),
  reason TEXT,
  changed_at TIMESTAMPTZ DEFAULT now()
);
```

---

# 👨‍💼 ADMIN SIDE — Full Attendance Control

---

## A1. Attendance Home Screen

### Layout:
```
📅 উপস্থিতি ব্যবস্থাপনা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

আজকের তারিখ: ০৮ এপ্রিল ২০২৫, মঙ্গলবার

┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ 📊 আজকের │ │ 🟢 উপস্থিত│ │ 🔴 অনুপস্থিত│ │ ⚠️ <৭৫%  │
│ সেশন     │ │           │ │           │ │ শিক্ষার্থী│
│   3/5    │ │   82%     │ │   18%     │ │   4 জন   │
└──────────┘ └──────────┘ └──────────┘ └──────────┘

━━━ আজকের ক্লাস ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────┐
│ 🟢 HSC Biology Batch 2025                       │
│ সম্পন্ন হয়েছে  |  ৩৫/৪০ উপস্থিত (৮৮%)          │
│ [📊 রিপোর্ট দেখুন]  [✏️ সম্পাদনা]               │
└─────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────┐
│ 🟢 HSC Chemistry Batch                          │
│ সম্পন্ন হয়েছে  |  ২৮/৩২ উপস্থিত (৮৭%)          │
│ [📊 রিপোর্ট দেখুন]  [✏️ সম্পাদনা]               │
└─────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────┐
│ ⏳ SSC Math Batch                               │
│ এখনও শুরু হয়নি  |  ৪৫ জন enrolled             │
│ [▶️ উপস্থিতি শুরু করুন]                         │
└─────────────────────────────────────────────────┘

[➕ নতুন উপস্থিতি শুরু করুন]
```

---

## A2. Start Attendance Screen

```
উপস্থিতি শুরু করুন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

তারিখ:
┌──────────────────────────────────┐
│ 📅 ০৮ এপ্রিল ২০২৫  ▼            │
└──────────────────────────────────┘
(default: আজকে, editable for past dates)

কোর্স নির্বাচন:
┌──────────────────────────────────┐
│ 📚 HSC Biology Batch 2025  ▼     │
└──────────────────────────────────┘

enrolled: ৪০ জন শিক্ষার্থী

নোট (optional):
┌──────────────────────────────────┐
│ যেমন: অতিরিক্ত ক্লাস, পরীক্ষার দিন│
└──────────────────────────────────┘

⚠️ এই তারিখে এই কোর্সের session
   ইতোমধ্যে আছে — সম্পাদনা করবেন?
   (যদি আগে থেকে থাকে)

┌──────────────────────────────────────┐
│    [▶️  উপস্থিতি শুরু করুন]          │
└──────────────────────────────────────┘
```

---

## A3. 🎯 ATTENDANCE TAKING SCREEN (মূল Feature)

এটাই সবচেয়ে গুরুত্বপূর্ণ screen। Admin class-এ বসে একটা একটা করে student-এর নাম দেখে Present/Absent করবে।

### Full Screen Layout:

```
┌─────────────────────────────────────────────────────┐
│ ✕  HSC Biology Batch          ০৮ এপ্রিল ২০২৫       │
│    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│    ████████████████████░░░░░  12/40  (30%)          │
│                                                     │
│                                                     │
│              ┌─────────────────────┐               │
│              │                     │               │
│              │    👤               │               │
│              │   (Photo)           │               │
│              │                     │               │
│              └─────────────────────┘               │
│                                                     │
│                  রহিম উদ্দিন                         │
│               RCC-2025-012                          │
│               Roll: ১২                              │
│                                                     │
│  ┌────────────────────┐  ┌────────────────────┐    │
│  │                    │  │                    │    │
│  │    ✅  উপস্থিত     │  │    ❌  অনুপস্থিত   │    │
│  │                    │  │                    │    │
│  └────────────────────┘  └────────────────────┘    │
│                                                     │
│   [◀ আগের]    [⚑ পরে দেখব]    [🗂️ তালিকা]         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Detailed Behavior:

**Progress Bar:**
- LinearProgressIndicator (top, animated)
- "12/40" counter
- Color: primary blue → green যখন শেষ হয়

**Student Card:**
- Photo: CircleAvatar (100px) — Supabase Storage থেকে, না থাকলে initials
- Name: Bengali, 24px bold
- ID + Roll number

**PRESENT Button:**
- ✅ বড় (full-width-এর 45%), height: 80px
- Color: #27AE60 (Green)
- Bengali label: "উপস্থিত"
- Tap করলে:
  1. Supabase-এ `present` save (upsert)
  2. HapticFeedback.mediumImpact()
  3. Brief green flash animation (0.2s)
  4. Automatically next student-এ slide (0.3s delay)

**ABSENT Button:**
- ❌ বড় (full-width-এর 45%), height: 80px
- Color: #E74C3C (Red)
- Bengali label: "অনুপস্থিত"
- Same behavior, red flash

**Bottom Actions:**
- `[◀ আগের]` — আগের student-এ ফিরে যাও (status change করা যাবে)
- `[⚑ পরে দেখব]` — Skip করো, শেষে আবার আসবে
- `[🗂️ তালিকা]` — Grid Navigator খোলে

### Slide Animation (Auto-advance):
```
Present/Absent press
    ↓ (0.2s flash animation)
Current card slides LEFT (out)
    ↓ (0.3s)
Next student card slides in from RIGHT
```

### Last Student:
```
সবাই হয়ে গেছে! 🎉
━━━━━━━━━━━━━━━━━━━━━━━━

উপস্থিত:   ৩৫ জন (৮৭.৫%)
অনুপস্থিত: ৫ জন  (১২.৫%)
মোট:        ৪০ জন

অনুপস্থিত শিক্ষার্থীরা:
• করিম মিয়া (RCC-2025-008)
• সাদিয়া খানম (RCC-2025-021)
• ...

[✅ সম্পন্ন করুন]  [🔄 আবার চেক করুন]
```

---

## A4. Grid Navigator (Bottom Sheet)

`[🗂️ তালিকা]` press করলে আসবে:

```
সব শিক্ষার্থী — ৪০ জন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 [নাম দিয়ে খুঁজুন...]

┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│  ✅  │ │  ✅  │ │  ❌  │ │  ✅  │ │  🔵  │
│  রহিম │ │ সাদিয়া│ │ করিম │ │ নাজমা│ │  আমি  │
│  01  │ │  02  │ │  03  │ │  04  │ │  05  │
└──────┘ └──────┘ └──────┘ └──────┘ └──────┘
┌──────┐ ┌──────┐ ┌──────┐ ...
│  ✅  │ │  ⬜  │ │  ✅  │
│ তানভীর│ │ রাফি  │ │ মিম   │
│  06  │ │  07  │ │  08  │
└──────┘ └──────┘ └──────┘

Color Legend:
🟢 ✅ উপস্থিত  🔴 ❌ অনুপস্থিত
🔵 🔵 বর্তমান  ⬜ ⬜ চিহ্নিত হয়নি
🟡 ⚑ পরে দেখব
```

- Tap on any cell → সরাসরি ওই student-এ চলে যাও
- তালিকা বন্ধ করলে সেখান থেকে continue হবে

---

## A5. Past Attendance Edit

### কীভাবে access করবে:
Attendance Home → Past session → "✏️ সম্পাদনা"

```
উপস্থিতি সম্পাদনা
০৫ এপ্রিল ২০২৫ | HSC Biology Batch
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

উপস্থিত: ৩৫  অনুপস্থিত: ৫  মোট: ৪০

শিক্ষার্থী তালিকা:

┌────────────────────────────────────────────┐
│ ✅ রহিম উদ্দিন        RCC-2025-012          │
│    [উপস্থিত ▼]  ← DropdownButton            │
└────────────────────────────────────────────┘
┌────────────────────────────────────────────┐
│ ❌ করিম মিয়া          RCC-2025-008          │
│    [অনুপস্থিত ▼]  ← tap to change           │
└────────────────────────────────────────────┘

পরিবর্তনের কারণ: [              ] (optional)

[💾 পরিবর্তন সংরক্ষণ করুন]
```

প্রতিটি change `attendance_edit_log` table-এ save হবে।

---

## A6. Attendance Reports

### Report 1 — Daily Report (একটি দিনের):

```
উপস্থিতি রিপোর্ট — ০৮ এপ্রিল ২০২৫
HSC Biology Batch 2025
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

মোট শিক্ষার্থী: ৪০
উপস্থিত:   ৩৫  (৮৭.৫%)
অনুপস্থিত:  ৫   (১২.৫%)

উপস্থিত শিক্ষার্থী:
০১. রহিম উদ্দিন      ✅
০২. সাদিয়া ইসলাম    ✅
০৩. তানভীর হোসেন    ✅
...

অনুপস্থিত শিক্ষার্থী:
০৩. করিম মিয়া       ❌
০৮. রাফি আহমেদ      ❌
...

[📄 PDF Download]  [📱 SMS পাঠাও অনুপস্থিতদের]
```

### Report 2 — Student-wise Calendar View:

```
রহিম উদ্দিন — উপস্থিতির ইতিহাস
HSC Biology Batch  |  ফিল্টার: [এপ্রিল ২০২৫ ▼]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

       রবি   সোম   মঙ্গল  বুধ   বৃহ   শুক্র  শনি
              ✅    ✅     ❌    ✅    ✅
  ✅   ❌    ✅    ✅     ✅
  ✅   ✅    ✅    ❌     ✅    ✅

মোট ক্লাস: ১৮   উপস্থিত: ১৫   অনুপস্থিত: ৩
উপস্থিতির হার: ৮৩.৩%

[পূর্ববর্তী মাস ◀]                  [▶ পরবর্তী মাস]
```

### Report 3 — Course-wise Monthly Summary:

```
HSC Biology Batch — এপ্রিল ২০২৫
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

নং | নাম              | মোট  | উপস্থিত | অনুপস্থিত | হার
01 | রহিম উদ্দিন      |  18  |    15   |     3     | 83%
02 | সাদিয়া ইসলাম    |  18  |    18   |     0     | 100%
03 | করিম মিয়া        |  18  |    10   |     8     | 56% ⚠️
...

⚠️ সতর্কতা: ৭৫%-এর নিচে ৩ জন শিক্ষার্থী

[📄 PDF Download]  [📱 SMS পাঠাও ⚠️ তালিকাকে]
```

### Report 4 — Attendance Trend (Chart):
- Line chart: last 30 days average attendance %
- Bar chart: per-student comparison

### Report 5 — <75% Warning List:
```
উপস্থিতি সতর্কতা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ নিচের শিক্ষার্থীরা ৭৫%-এর নিচে:

করিম মিয়া      — ৫৬%  ❗ (HSC Biology)
রাফি আহমেদ     — ৬২%  ⚠️ (HSC Biology)
নাজমুল হক      — ৭০%  ⚠️ (HSC Chem)

[📱 সবাইকে Warning SMS পাঠাও]
[📄 অভিভাবকদের জন্য রিপোর্ট]
```

---

## A7. Attendance Settings

```
উপস্থিতি সেটিংস
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ সতর্কতার সীমা:
   উপস্থিতি [৭৫]% এর নিচে হলে alert

📱 Auto SMS:
   [✅] ৭৫%-এর নিচে হলে student-কে SMS

Student সাজানোর ক্রম:
   [● Roll Number অনুযায়ী]
   [  নাম অনুযায়ী (A-Z)]
   [  নাম অনুযায়ী (বাংলা)]
   [  যোগদানের তারিখ অনুযায়ী]

Auto-advance delay:
   Present/Absent press করার পর কতক্ষণ পরে next-এ যাবে:
   [0.3] সেকেন্ড  (Slider: 0 – 1.0)

Default Status:
   নতুন session-এ default কী হবে?
   [● সব Absent থেকে শুরু (recommended)]
   [  সব Present থেকে শুরু]
```

---

# 🎓 STUDENT SIDE — Attendance View

---

## S1. Attendance Widget (Dashboard-এ):

```
┌──────────────────────────────────────┐
│ 📅 আমার উপস্থিতি — এপ্রিল ২০২৫      │
│                                      │
│       ╭──────────────╮               │
│       │    83.3%     │  ← Circular   │
│       │  ১৫/১৮ ক্লাস│    Progress   │
│       ╰──────────────╯               │
│                                      │
│  🟢 নিয়মিত     [বিস্তারিত →]          │
└──────────────────────────────────────┘
```

---

## S2. Full Attendance Screen (Student):

```
আমার উপস্থিতি
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

কোর্স: [HSC Biology Batch ▼]
মাস:   [◀ এপ্রিল ২০২৫ ▶]

Stats:
┌──────────┐ ┌──────────┐ ┌──────────┐
│ মোট ক্লাস│ │ উপস্থিত  │ │ অনুপস্থিত│
│    ১৮    │ │    ১৫    │ │    ৩     │
└──────────┘ └──────────┘ └──────────┘

উপস্থিতির হার:
━━━━━━━━━━━━━━━━━━━━━━ ৮৩.৩%
🟢 নিয়মিত (৭৫%-এর উপরে)

ক্যালেন্ডার ভিউ:
     রবি  সোম  মঙ্গল  বুধ  বৃহ  শুক্র  শনি
                ✅    ✅    ❌   ✅   ✅
      ✅   ❌   ✅    ✅   ✅
      ✅   ✅   ✅    ❌   ✅   ✅

🟢 ✅ উপস্থিত   🔴 ❌ অনুপস্থিত   ⚪ ক্লাস নেই
```

### Warning State (যদি <75%):
```
⚠️ সতর্কতা!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
তোমার উপস্থিতি ৬৮% — ৭৫%-এর নিচে।

আর ৩টি ক্লাস অনুপস্থিত থাকলে
শিক্ষকের অনুমতি ছাড়া পরীক্ষায়
বসতে সমস্যা হতে পারে।

অনুগ্রহ করে নিয়মিত ক্লাসে আসো। 🙏
```

---

## S3. Notifications (Attendance):

**Push Notification:**
- Weekly: *"এই সপ্তাহে তোমার উপস্থিতি ৮৩%। চালিয়ে যাও! 💪"*
- Warning: *"সতর্কতা! তোমার উপস্থিতি ৬৮% — ৭৫%-এর নিচে।"*

**SMS (অভিভাবকের নম্বরে):**
```
"প্রিয় অভিভাবক, আপনার সন্তান রহিম উদ্দিন
এই মাসে ১৮টির মধ্যে ১৫টি ক্লাসে
উপস্থিত ছিল (৮৩%)।
— Radiance Coaching Center"
```

---

# 🔧 FLUTTER IMPLEMENTATION

## Screen Widget Structure:

```dart
class AttendanceTakingScreen extends ConsumerStatefulWidget {
  final String courseId;
  final DateTime sessionDate;
}

class _AttendanceTakingState extends ConsumerState<AttendanceTakingScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  int _currentIndex = 0;
  late List<UserModel> _students;       // sorted by roll/name
  Map<String, String> _answers = {};    // studentId → 'present'/'absent'
  Set<String> _skipped = {};            // skipped student IDs
  late String _sessionId;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _initSession();
  }

  Future<void> _markAttendance(String status) async {
    final student = _students[_currentIndex];

    // 1. Save to Supabase immediately
    await ref.read(attendanceRepositoryProvider).upsertRecord(
      sessionId: _sessionId,
      studentId: student.id,
      status: status,
    );

    // 2. Update local state
    setState(() => _answers[student.id] = status);

    // 3. Haptic feedback
    HapticFeedback.mediumImpact();

    // 4. Brief flash then advance
    await Future.delayed(const Duration(milliseconds: 300));
    _goNext();
  }

  void _goNext() {
    if (_currentIndex < _students.length - 1) {
      _slideController.reset();
      setState(() => _currentIndex++);
      _slideController.forward();
    } else {
      _showCompletionDialog();
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  // Build UI
  @override
  Widget build(BuildContext context) {
    final student = _students[_currentIndex];
    final currentStatus = _answers[student.id];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildProgressBar(),
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildStudentCard(student, currentStatus),
            ),
          ),
          _buildActionButtons(student),
          _buildBottomNav(),
        ]),
      ),
    );
  }

  Widget _buildActionButtons(UserModel student) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        Expanded(
          child: _AttendanceButton(
            label: 'উপস্থিত',
            icon: Icons.check_circle,
            color: const Color(0xFF27AE60),
            isSelected: _answers[student.id] == 'present',
            onTap: () => _markAttendance('present'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _AttendanceButton(
            label: 'অনুপস্থিত',
            icon: Icons.cancel,
            color: const Color(0xFFE74C3C),
            isSelected: _answers[student.id] == 'absent',
            onTap: () => _markAttendance('absent'),
          ),
        ),
      ]),
    );
  }
}

// Big attendance button widget
class _AttendanceButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
}
```

## Repository:

```dart
class AttendanceRepository {
  final SupabaseClient _supabase;

  // Session create or get existing
  Future<String> getOrCreateSession({
    required String courseId,
    required DateTime date,
    required String adminId,
  }) async {
    final existing = await _supabase
        .from('attendance_sessions')
        .select('id')
        .eq('course_id', courseId)
        .eq('session_date', date.toIso8601String().substring(0, 10))
        .maybeSingle();
    if (existing != null) return existing['id'];
    
    final res = await _supabase
        .from('attendance_sessions')
        .insert({'course_id': courseId, 'session_date': date.toIso8601String().substring(0,10), 'created_by': adminId})
        .select('id')
        .single();
    return res['id'];
  }

  // Single record upsert (called on every button press)
  Future<void> upsertRecord({
    required String sessionId,
    required String studentId,
    required String status, // 'present' | 'absent'
  }) async {
    await _supabase.from('attendance_records').upsert({
      'session_id': sessionId,
      'student_id': studentId,
      'status': status,
      'marked_at': DateTime.now().toIso8601String(),
    }, onConflict: 'session_id,student_id');
  }

  // Complete a session — update counts
  Future<void> completeSession(String sessionId) async {
    final records = await _supabase
        .from('attendance_records')
        .select('status')
        .eq('session_id', sessionId);
    
    final presentCount = records.where((r) => r['status'] == 'present').length;
    
    await _supabase.from('attendance_sessions').update({
      'is_completed': true,
      'present_count': presentCount,
      'absent_count': records.length - presentCount,
      'total_students': records.length,
    }).eq('id', sessionId);
  }

  // Edit a past record (with log)
  Future<void> editRecord({
    required String recordId,
    required String newStatus,
    required String adminId,
    String? reason,
  }) async {
    final old = await _supabase
        .from('attendance_records')
        .select('status')
        .eq('id', recordId)
        .single();
    
    await _supabase.from('attendance_records')
        .update({'status': newStatus}).eq('id', recordId);
    
    await _supabase.from('attendance_edit_log').insert({
      'record_id': recordId,
      'old_status': old['status'],
      'new_status': newStatus,
      'changed_by': adminId,
      'reason': reason,
    });
  }

  // Student monthly attendance summary
  Future<Map<DateTime, String>> getStudentMonthlyAttendance({
    required String studentId,
    required String courseId,
    required DateTime month,
  }) async {
    // Returns Map<date, status> for calendar view
  }

  // Course monthly report
  Future<List<StudentAttendanceSummary>> getCourseMonthlyReport({
    required String courseId,
    required DateTime month,
  }) async { ... }
}
```

---

# 📊 KEY SQL QUERIES

```sql
-- একটি course-এর এই মাসের attendance summary (per student)
SELECT
  u.full_name_bn,
  u.student_id,
  COUNT(*) AS total_classes,
  COUNT(CASE WHEN ar.status = 'present' THEN 1 END) AS present,
  COUNT(CASE WHEN ar.status = 'absent'  THEN 1 END) AS absent,
  ROUND(
    COUNT(CASE WHEN ar.status = 'present' THEN 1 END) * 100.0 / COUNT(*), 1
  ) AS percentage
FROM attendance_records ar
JOIN attendance_sessions ats ON ar.session_id = ats.id
JOIN users u ON ar.student_id = u.id
WHERE ats.course_id = 'COURSE_UUID'
  AND DATE_TRUNC('month', ats.session_date) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY u.id, u.full_name_bn, u.student_id
ORDER BY percentage ASC;

-- <75% সতর্কতা list
SELECT u.full_name_bn, u.phone, u.guardian_phone,
  ROUND(
    COUNT(CASE WHEN ar.status = 'present' THEN 1 END) * 100.0 / COUNT(*), 1
  ) AS pct
FROM attendance_records ar
JOIN attendance_sessions ats ON ar.session_id = ats.id
JOIN users u ON ar.student_id = u.id
WHERE ats.course_id = 'COURSE_UUID'
  AND DATE_TRUNC('month', ats.session_date) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY u.id, u.full_name_bn, u.phone, u.guardian_phone
HAVING ROUND(
  COUNT(CASE WHEN ar.status = 'present' THEN 1 END) * 100.0 / COUNT(*), 1
) < 75
ORDER BY pct ASC;

-- একজন student-এর calendar data (date → status)
SELECT ats.session_date, ar.status
FROM attendance_records ar
JOIN attendance_sessions ats ON ar.session_id = ats.id
WHERE ar.student_id = 'STUDENT_UUID'
  AND ats.course_id = 'COURSE_UUID'
  AND DATE_TRUNC('month', ats.session_date) = DATE_TRUNC('month', CURRENT_DATE)
ORDER BY ats.session_date;

-- আজকের সব course-এর session status
SELECT c.name, ats.is_completed, ats.present_count, ats.total_students
FROM attendance_sessions ats
JOIN courses c ON ats.course_id = c.id
WHERE ats.session_date = CURRENT_DATE
ORDER BY ats.created_at;
```

---

# ✅ FEATURE CHECKLIST

## Admin:
- [ ] Attendance Home Screen (today's overview)
- [ ] Start Attendance (date + course select)
- [ ] **Roll-call Taking Screen** (one by one, auto-advance)
- [ ] Present / Absent big buttons (80px height)
- [ ] Slide animation on advance
- [ ] Haptic feedback on button press
- [ ] Progress bar (X/Total)
- [ ] Grid Navigator (bottom sheet — all students overview)
- [ ] Jump to specific student from grid
- [ ] Skip / পরে দেখব
- [ ] Previous button (go back and change)
- [ ] Completion Summary Dialog
- [ ] Past attendance edit (with reason log)
- [ ] Edit log (who changed, when, why)
- [ ] Daily Report (PDF)
- [ ] Student-wise Calendar View
- [ ] Course Monthly Summary Table (PDF)
- [ ] <75% Warning List with bulk SMS
- [ ] Attendance Trend Chart (fl_chart)
- [ ] Auto-advance speed setting
- [ ] Default sort order setting (roll/name)
- [ ] Warning threshold setting (default 75%)
- [ ] Auto SMS on <75% toggle

## Student:
- [ ] Dashboard attendance widget (circular progress)
- [ ] Monthly Calendar View (✅❌ per day)
- [ ] Stats: total/present/absent/percentage
- [ ] Course switcher (multiple enrollments)
- [ ] Month navigation (previous months)
- [ ] Warning banner (<75%)
- [ ] Push notification (weekly summary)
- [ ] Push notification (warning)
- [ ] SMS to guardian (monthly summary + warning)
